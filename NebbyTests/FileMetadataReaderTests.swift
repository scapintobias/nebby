import Foundation
import XCTest
@testable import Nebby

final class FileMetadataReaderTests: XCTestCase {
    private var fixtureDirectory: URL!

    override func setUpWithError() throws {
        fixtureDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let fixtureDirectory {
            try? FileManager.default.removeItem(at: fixtureDirectory)
        }
    }

    func testRegularFileHasFactualMetadataAndNonImageDimensionsAreInapplicable() throws {
        let url = fixtureDirectory.appending(path: "notes.txt")
        let contents = Data("Nebby metadata".utf8)
        try contents.write(to: url)

        let item = FileMetadataReader().read(url)

        XCTAssertEqual(item.id, url.standardizedFileURL)
        XCTAssertEqual(item.name, "notes.txt")
        XCTAssertEqual(item.itemKind, .available(.file))
        XCTAssertEqual(item.byteSize, .available(Int64(contents.count)))
        XCTAssertNotNil(item.contentType.value)
        XCTAssertNotNil(item.kindDescription.value)
        XCTAssertNotNil(item.creationDate.value)
        XCTAssertNotNil(item.modificationDate.value)
        XCTAssertEqual(item.imageDimensions, .notApplicable)
        XCTAssertEqual(item.systemIcon.fileURL, url.standardizedFileURL)
    }

    func testFolderIsDistinguishedWithoutInventingRecursiveSize() throws {
        let url = fixtureDirectory.appending(path: "A Folder", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)

        let item = FileMetadataReader().read(url)

        XCTAssertEqual(item.itemKind, .available(.folder))
        XCTAssertEqual(item.byteSize, .notApplicable)
        XCTAssertEqual(item.imageDimensions, .notApplicable)
    }

    func testSymbolicLinkRetainsItsOwnIdentityAndClassification() throws {
        let targetURL = fixtureDirectory.appending(path: "target.txt")
        let linkURL = fixtureDirectory.appending(path: "target-link.txt")
        try Data("link target".utf8).write(to: targetURL)
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: targetURL)

        let item = FileMetadataReader().read(linkURL)

        XCTAssertEqual(item.id, linkURL.standardizedFileURL)
        XCTAssertEqual(item.url, linkURL.standardizedFileURL)
        XCTAssertEqual(item.url.path, linkURL.standardizedFileURL.path)
        XCTAssertNotEqual(item.url, targetURL.standardizedFileURL)
        XCTAssertEqual(item.name, "target-link.txt")
        XCTAssertEqual(item.itemKind, .available(.symbolicLink))
        XCTAssertEqual(item.systemIcon.fileURL, linkURL.standardizedFileURL)
    }

    func testPNGDimensionsAreReadWithoutUsingZeroAsFallback() throws {
        let url = fixtureDirectory.appending(path: "pixel.png")
        let png = try XCTUnwrap(Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAIAAAA2iEnWAAAAFElEQVR4nGP4z8DAwMDAxAADCBYAE7cBBfpib1sAAAAASUVORK5CYII="
        ))
        try png.write(to: url)

        let item = FileMetadataReader().read(url)

        XCTAssertEqual(item.imageDimensions, .available(.init(width: 2, height: 3)))
    }

    func testCorruptImageKeepsTheRecordAndReportsOnlyUnavailableDimensions() throws {
        let url = fixtureDirectory.appending(path: "corrupt.png")
        let contents = Data("not an image".utf8)
        try contents.write(to: url)

        let item = FileMetadataReader().read(url)

        XCTAssertEqual(item.name, "corrupt.png")
        XCTAssertEqual(item.itemKind, .available(.file))
        XCTAssertEqual(item.byteSize, .available(Int64(contents.count)))
        XCTAssertNotNil(item.contentType.value)
        guard case let .unavailable(issue) = item.imageDimensions else {
            return XCTFail("Expected unavailable image dimensions")
        }
        XCTAssertTrue([.readFailed, .unsupported].contains(issue.code))
        XCTAssertFalse(issue.detail.isEmpty)
    }

    func testExtensionlessFileRemainsAValidFactualRecord() throws {
        let url = fixtureDirectory.appending(path: "extensionless")
        let contents = Data("Nebby".utf8)
        try contents.write(to: url)

        let item = FileMetadataReader().read(url)

        XCTAssertEqual(item.name, "extensionless")
        XCTAssertEqual(item.itemKind, .available(.file))
        XCTAssertEqual(item.byteSize, .available(Int64(contents.count)))
        XCTAssertNotNil(item.kindDescription.value)
        XCTAssertEqual(item.imageDimensions, .notApplicable)
    }

    func testUnreadableItemProducesPerFieldFailuresInsteadOfAFalseEmptyRecord() {
        let url = fixtureDirectory.appending(path: "missing-file")

        let item = FileMetadataReader().read(url)

        assertReadFailure(item.itemKind)
        assertReadFailure(item.contentType)
        assertReadFailure(item.kindDescription)
        assertReadFailure(item.byteSize)
        assertReadFailure(item.creationDate)
        assertReadFailure(item.modificationDate)
        assertReadFailure(item.imageDimensions)
    }

    func testParentSelectionPublishesLoadedRecordsInSelectionOrder() async throws {
        let firstURL = fixtureDirectory.appending(path: "first.txt")
        let secondURL = fixtureDirectory.appending(path: "second.txt")
        try Data("first".utf8).write(to: firstURL)
        try Data("second".utf8).write(to: secondURL)

        let selection = ParentSelection()
        let revision = selection.beginInput()
        selection.replace(with: [secondURL, firstURL], for: revision)

        for _ in 0..<100 where selection.isLoadingMetadata {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertFalse(selection.isLoadingMetadata)
        XCTAssertEqual(selection.items.map(\.name), ["second.txt", "first.txt"])
    }

    private func assertReadFailure<Value>(
        _ value: MetadataValue<Value>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .unavailable(issue) = value else {
            return XCTFail("Expected unavailable metadata", file: file, line: line)
        }
        XCTAssertEqual(issue.code, .readFailed, file: file, line: line)
        XCTAssertFalse(issue.detail.isEmpty, file: file, line: line)
    }
}
