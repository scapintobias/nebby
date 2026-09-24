import Foundation
import UniformTypeIdentifiers
import XCTest
@testable import Nebby

final class SelectionAggregatorTests: XCTestCase {
    private let reader = SelectionAggregator()
    private let day = Date(timeIntervalSince1970: 1_700_000_000)
    private let later = Date(timeIntervalSince1970: 1_700_086_400)
    private let failure = MetadataIssue(code: .readFailed, detail: "Fixture read failed")

    func testEmptyAndSingleItem() {
        let empty = reader.aggregate([])
        XCTAssertEqual(empty.itemCount, 0)
        XCTAssertNil(empty.size.summary)
        XCTAssertNil(empty.types.summary)
        XCTAssertNil(empty.location.summary)
        XCTAssertEqual(empty.dimensions.coverage.applicableCount, 0)

        let item = fixture("a.png", type: .png, size: 12, dimensions: .init(width: 2, height: 3))
        let single = reader.aggregate([item])
        XCTAssertEqual(single.size.summary?.knownBytes, 12)
        XCTAssertTrue(single.size.coverage.isComplete)
        XCTAssertEqual(single.creationDate.summary, .single(day))
        XCTAssertEqual(single.dimensions.summary, .init(
            minimumWidth: 2, maximumWidth: 2, minimumHeight: 3, maximumHeight: 3
        ))
        XCTAssertEqual(single.location.summary, .shared(item.url.deletingLastPathComponent()))
    }

    func testHomogeneousImagesHaveTotalDistributionRangesAndSharedLocation() {
        let first = fixture("a.png", type: .png, size: 10, created: day,
                            dimensions: .init(width: 20, height: 80))
        let second = fixture("b.png", type: .png, size: 15, created: later,
                             dimensions: .init(width: 50, height: 30))
        let input = [second, first]
        let aggregate = reader.aggregate(input)

        XCTAssertEqual(input.map(\.name), ["b.png", "a.png"])
        XCTAssertEqual(aggregate.size.summary?.knownBytes, 25)
        XCTAssertTrue(aggregate.size.coverage.isComplete)
        XCTAssertEqual(aggregate.types.summary, [.init(identifier: UTType.png.identifier, count: 2)])
        XCTAssertEqual(aggregate.creationDate.summary, .range(minimum: day, maximum: later))
        XCTAssertEqual(aggregate.modificationDate.summary, .single(day))
        XCTAssertEqual(aggregate.dimensions.summary, .init(
            minimumWidth: 20, maximumWidth: 50, minimumHeight: 30, maximumHeight: 80
        ))
        XCTAssertEqual(aggregate.dimensions.coverage.availableCount, 2)
        XCTAssertEqual(aggregate.location.summary, .shared(first.url.deletingLastPathComponent()))
    }

    func testMixedTypesAreDeterministicAndMissingTypeIsExplicit() {
        let items = [
            fixture("b.txt", type: .plainText),
            fixture("a.png", type: .png),
            fixture("c.bin", type: nil),
            fixture("d.png", type: .png),
        ]
        let aggregate = reader.aggregate(items)
        XCTAssertEqual(aggregate.types.summary, [
            .init(identifier: UTType.png.identifier, count: 2),
            .init(identifier: UTType.plainText.identifier, count: 1),
        ].sorted { $0.identifier < $1.identifier })
        XCTAssertEqual(aggregate.types.coverage.availableCount, 3)
        XCTAssertEqual(aggregate.types.coverage.unavailableCount, 1)
        XCTAssertFalse(aggregate.types.coverage.isComplete)
    }

    func testFolderAndFilesDoNotProduceFalseCompleteSize() {
        let items = [fixture("one.txt", type: .plainText, size: 10),
                     fixture("two.txt", type: .plainText, size: 20),
                     fixture("folder", type: .folder, kind: .folder, sizeValue: .notApplicable)]
        let aggregate = reader.aggregate(items)
        XCTAssertEqual(aggregate.size.summary?.knownBytes, 30)
        XCTAssertEqual(aggregate.size.coverage.applicableCount, 2)
        XCTAssertEqual(aggregate.size.coverage.availableCount, 2)
        XCTAssertEqual(aggregate.size.coverage.notApplicableCount, 1)
        XCTAssertFalse(aggregate.size.coverage.isComplete)
        XCTAssertEqual(aggregate.classifications.summary, [
            .init(kind: .file, count: 2), .init(kind: .folder, count: 1),
        ])
    }

    func testDimensionsSeparateNonImagesFromCorruptImages() {
        let items = [fixture("good.png", type: .png, dimensions: .init(width: 4, height: 5)),
                     fixture("bad.png", type: .png, dimensionsValue: .unavailable(failure)),
                     fixture("note.txt", type: .plainText, dimensionsValue: .notApplicable)]
        let aggregate = reader.aggregate(items)
        XCTAssertEqual(aggregate.dimensions.coverage.applicableCount, 2)
        XCTAssertEqual(aggregate.dimensions.coverage.availableCount, 1)
        XCTAssertEqual(aggregate.dimensions.coverage.unavailableCount, 1)
        XCTAssertEqual(aggregate.dimensions.coverage.notApplicableCount, 1)
        XCTAssertEqual(aggregate.dimensions.summary, .init(
            minimumWidth: 4, maximumWidth: 4, minimumHeight: 5, maximumHeight: 5
        ))
    }

    func testMixedLocationsDoNotBecomeCommonAncestor() {
        let items = [fixture("a.txt", parent: "/tmp/Nebby/A"),
                     fixture("b.txt", parent: "/tmp/Nebby/B")]
        XCTAssertEqual(reader.aggregate(items).location.summary, .mixed)
    }

    func testSymbolicLinkKeepsItsClassification() {
        let aggregate = reader.aggregate([
            fixture("target.txt"), fixture("link.txt", kind: .symbolicLink),
        ])
        XCTAssertEqual(aggregate.classifications.summary, [
            .init(kind: .file, count: 1), .init(kind: .symbolicLink, count: 1),
        ])
    }

    func testMissingMetadataAndUnknownApplicabilityRemainVisible() {
        let missing = fixture("missing", type: nil, kindValue: .unavailable(failure),
                              sizeValue: .unavailable(failure), dimensionsValue: .unavailable(failure),
                              creationValue: .unavailable(failure))
        let aggregate = reader.aggregate([fixture("good.png", type: .png, size: 4), missing])
        XCTAssertEqual(aggregate.size.summary?.knownBytes, 4)
        XCTAssertEqual(aggregate.size.coverage.unknownApplicabilityCount, 1)
        XCTAssertEqual(aggregate.creationDate.coverage.unavailableCount, 1)
        XCTAssertEqual(aggregate.dimensions.coverage.unknownApplicabilityCount, 1)
        XCTAssertEqual(aggregate.classifications.coverage.unavailableCount, 1)
    }

    func testSizeOverflowDoesNotReturnWrappedTotal() {
        let aggregate = reader.aggregate([
            fixture("a", size: Int64.max), fixture("b", size: 1),
        ])
        XCTAssertTrue(aggregate.size.summary?.overflowed == true)
        XCTAssertNil(aggregate.size.summary?.knownBytes)
        XCTAssertEqual(aggregate.size.coverage.availableCount, 2)
    }

    func testRealFileFixturesFlowThroughMetadataReaderAndAggregator() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let good = directory.appending(path: "good.png")
        let corrupt = directory.appending(path: "corrupt.png")
        let text = directory.appending(path: "notes.txt")
        let folder = directory.appending(path: "folder", directoryHint: .isDirectory)
        let link = directory.appending(path: "link.txt")
        let png = try XCTUnwrap(Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAIAAAA2iEnWAAAAFElEQVR4nGP4z8DAwMDAxAADCBYAE7cBBfpib1sAAAAASUVORK5CYII="
        ))
        try png.write(to: good)
        try Data("broken".utf8).write(to: corrupt)
        try Data("notes".utf8).write(to: text)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: text)

        let metadataReader = FileMetadataReader()
        let records = [good, corrupt, text, folder, link].map(metadataReader.read)
        let images = reader.aggregate(Array(records.prefix(2)))
        XCTAssertEqual(images.dimensions.coverage.applicableCount, 2)
        XCTAssertEqual(images.dimensions.coverage.availableCount, 1)
        XCTAssertEqual(images.dimensions.coverage.unavailableCount, 1)

        let mixed = reader.aggregate(records)
        XCTAssertEqual(mixed.itemCount, 5)
        XCTAssertEqual(mixed.size.coverage.notApplicableCount, 1)
        XCTAssertEqual(mixed.dimensions.coverage.notApplicableCount, 3)
        XCTAssertEqual(mixed.classifications.summary, [
            .init(kind: .file, count: 3),
            .init(kind: .folder, count: 1),
            .init(kind: .symbolicLink, count: 1),
        ])
        XCTAssertEqual(mixed.location.summary, .shared(directory))
    }

    private func fixture(
        _ name: String,
        parent: String = "/tmp/Nebby/A",
        type: UTType? = .plainText,
        kind: FileItem.ItemKind = .file,
        size: Int64 = 1,
        created: Date? = nil,
        dimensions: FileItem.PixelDimensions? = nil,
        kindValue: MetadataValue<FileItem.ItemKind>? = nil,
        sizeValue: MetadataValue<Int64>? = nil,
        dimensionsValue: MetadataValue<FileItem.PixelDimensions>? = nil,
        creationValue: MetadataValue<Date>? = nil
    ) -> FileItem {
        let url = URL(fileURLWithPath: parent).appending(path: name)
        return FileItem(
            id: url, url: url, name: name,
            itemKind: kindValue ?? .available(kind),
            contentType: type.map(MetadataValue.available) ?? .unavailable(failure),
            kindDescription: .available("Fixture"),
            byteSize: sizeValue ?? .available(size),
            creationDate: creationValue ?? .available(created ?? day),
            modificationDate: .available(day),
            imageDimensions: dimensionsValue ?? dimensions.map(MetadataValue.available) ?? .notApplicable,
            systemIcon: .init(fileURL: url)
        )
    }
}
