import Foundation
import UniformTypeIdentifiers
import XCTest
@testable import Nebby

final class InspectorPresentationTests: XCTestCase {
    func testOneItemGeneralKindOmitsAggregateCount() {
        let base = aggregate()
        let selection = AggregateSelection(
            itemCount: 1,
            types: .init(summary: [.init(identifier: UTType.png.identifier, count: 1)],
                         coverage: counts(total: 1, applicable: 1, available: 1)),
            classifications: base.classifications, size: base.size,
            creationDate: base.creationDate, modificationDate: base.modificationDate,
            dimensions: base.dimensions, location: base.location
        )
        XCTAssertEqual(InspectorPresentation(aggregate: selection).kinds.text,
                       UTType.png.localizedDescription)
    }

    func testPartialSizeNeverLooksComplete() {
        let view = InspectorPresentation(aggregate: aggregate(
            size: .init(summary: .init(knownBytes: 1024, overflowed: false),
                        coverage: counts(total: 3, applicable: 2, available: 2, notApplicable: 1))
        ))
        XCTAssertTrue(view.size.text.contains("known"))
        XCTAssertTrue(view.signature.contains("known"))
        XCTAssertTrue(view.signature.contains("Applies to 2 of 3 items"))
    }

    func testLongTypeDistributionKeepsSignatureConcise() {
        let base = aggregate()
        let selection = AggregateSelection(
            itemCount: 5,
            types: .init(summary: [.init(identifier: UTType.jpeg.identifier, count: 1),
                                   .init(identifier: UTType.png.identifier, count: 1),
                                   .init(identifier: UTType.tiff.identifier, count: 1),
                                   .init(identifier: UTType.pdf.identifier, count: 1),
                                   .init(identifier: UTType.plainText.identifier, count: 1)],
                         coverage: counts(total: 5, applicable: 5, available: 5)),
            classifications: base.classifications, size: base.size,
            creationDate: base.creationDate, modificationDate: base.modificationDate,
            dimensions: base.dimensions, location: base.location
        )
        XCTAssertTrue(InspectorPresentation(aggregate: selection).signature.contains("2 more types"))
    }

    func testSymbolicLinkClassificationIsVisibleAlongsideTargetType() {
        let base = aggregate()
        let selection = AggregateSelection(
            itemCount: 1,
            types: .init(summary: [.init(identifier: UTType.plainText.identifier, count: 1)],
                         coverage: counts(total: 1, applicable: 1, available: 1)),
            classifications: .init(summary: [.init(kind: .symbolicLink, count: 1)],
                                   coverage: counts(total: 1, applicable: 1, available: 1)),
            size: base.size, creationDate: base.creationDate,
            modificationDate: base.modificationDate, dimensions: base.dimensions,
            location: base.location
        )
        let presentation = InspectorPresentation(aggregate: selection)
        XCTAssertTrue(presentation.signature.contains("1 symbolic link"))
        XCTAssertTrue(presentation.kinds.detail?.contains("1 symbolic link") == true)
    }

    func testIndependentDimensionBoundsAreNotCombinedIntoFalsePairs() {
        var selection = aggregate()
        selection = AggregateSelection(
            itemCount: selection.itemCount, types: selection.types, classifications: selection.classifications,
            size: selection.size, creationDate: selection.creationDate, modificationDate: selection.modificationDate,
            dimensions: .init(summary: .init(minimumWidth: 20, maximumWidth: 50,
                                              minimumHeight: 30, maximumHeight: 80),
                              coverage: counts(total: 3, applicable: 2, available: 2, notApplicable: 1)),
            location: selection.location
        )
        let values = InspectorPresentation(aggregate: selection).dimensions
        XCTAssertEqual(values.map(\.text), ["Width 20–50 px", "Height 30–80 px"])
        XCTAssertEqual(values.last?.detail, "Applies to 2 of 3 items")
    }

    func testUnavailableApplicableDimensionsStayDistinctFromInapplicable() {
        var selection = aggregate()
        selection = AggregateSelection(
            itemCount: selection.itemCount, types: selection.types, classifications: selection.classifications,
            size: selection.size, creationDate: selection.creationDate, modificationDate: selection.modificationDate,
            dimensions: .init(summary: .init(minimumWidth: 2, maximumWidth: 2,
                                              minimumHeight: 3, maximumHeight: 3),
                              coverage: counts(total: 3, applicable: 2, available: 1,
                                               unavailable: 1, notApplicable: 1)),
            location: selection.location
        )
        let value = InspectorPresentation(aggregate: selection).dimensions[0]
        XCTAssertEqual(value.text, "2 × 3 px")
        XCTAssertEqual(value.detail, "Applies to 2 of 3 items · 1 of 2 values available")
    }

    private func aggregate(size: AggregateField<ByteTotal>? = nil) -> AggregateSelection {
        let empty = counts(total: 3, applicable: 0, available: 0, notApplicable: 3)
        return AggregateSelection(
            itemCount: 3,
            types: .init(summary: [.init(identifier: UTType.png.identifier, count: 2)],
                         coverage: counts(total: 3, applicable: 3, available: 2, unavailable: 1)),
            classifications: .init(summary: nil, coverage: empty),
            size: size ?? .init(summary: nil, coverage: empty),
            creationDate: .init(summary: nil, coverage: empty),
            modificationDate: .init(summary: nil, coverage: empty),
            dimensions: .init(summary: nil, coverage: empty),
            location: .init(summary: .mixed, coverage: counts(total: 3, applicable: 3, available: 3))
        )
    }

    private func counts(total: Int, applicable: Int, available: Int,
                        unavailable: Int = 0, notApplicable: Int = 0) -> AggregateCoverage {
        AggregateCoverage(itemCount: total, applicableCount: applicable, availableCount: available,
                          unavailableCount: unavailable, notApplicableCount: notApplicable,
                          unknownApplicabilityCount: 0)
    }
}
