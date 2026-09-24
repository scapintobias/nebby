import Foundation
import UniformTypeIdentifiers
import XCTest
@testable import Nebby

final class PrototypeTagStateTests: XCTestCase {
    func testSharedMixedAndAbsentCoverage() {
        let items = fixtures(17)
        var tags = PrototypeTagState()
        tags.reset(for: items)
        XCTAssertEqual(tags.coverage(of: .travel, in: items), .init(present: 17, total: 17))
        XCTAssertEqual(tags.coverage(of: .favorites, in: items), .init(present: 5, total: 17))
        XCTAssertEqual(tags.coverage(of: .portfolio, in: items), .init(present: 0, total: 17))
        XCTAssertEqual(tags.coverage(of: .travel, in: items).state, .checked)
        XCTAssertEqual(tags.coverage(of: .favorites, in: items).state, .mixed)
        XCTAssertEqual(tags.coverage(of: .portfolio, in: items).state, .unchecked)
    }

    func testMixedToggleResolvesToCheckedAndSharedToggleToAbsent() {
        let items = fixtures(17)
        var tags = PrototypeTagState()
        tags.reset(for: items)
        tags.toggle(.favorites, in: items)
        XCTAssertEqual(tags.coverage(of: .favorites, in: items).state, .checked)
        tags.toggle(.favorites, in: items)
        XCTAssertEqual(tags.coverage(of: .favorites, in: items).state, .unchecked)
    }

    func testEditTargetsOnlyScopeAndPreservesParentAndScope() {
        let items = fixtures(17)
        let originalIDs = items.map(\.id)
        var scope = InspectionScope()
        scope.select(Set(items[6...9].map(\.id)), within: items)
        let originalScope = scope
        var tags = PrototypeTagState()
        tags.reset(for: items)
        tags.toggle(.portfolio, in: scope.items(in: items))
        XCTAssertEqual(tags.coverage(of: .portfolio, in: items).present, 4)
        XCTAssertEqual(tags.coverage(of: .portfolio, in: scope.items(in: items)).state, .checked)
        XCTAssertEqual(tags.coverage(of: .portfolio, in: Array(items[0...5])).state, .unchecked)
        XCTAssertEqual(tags.coverage(of: .travel, in: items).state, .checked)
        XCTAssertEqual(items.map(\.id), originalIDs)
        XCTAssertEqual(scope, originalScope)
    }

    func testReplacementResetsEditableStateEvenForSameIdentities() {
        let items = fixtures(3)
        var tags = PrototypeTagState()
        tags.reset(for: items)
        tags.set(.portfolio, present: true, in: items)
        tags.reset(for: items)
        XCTAssertEqual(tags.coverage(of: .portfolio, in: items).state, .unchecked)
        let newItems = fixtures(2, prefix: "replacement")
        tags.reset(for: newItems)
        XCTAssertEqual(tags.parentIDs, newItems.map(\.id))
        XCTAssertNil(tags.membership[items[0].id])
    }

    private func fixtures(_ count: Int, prefix: String = "file") -> [FileItem] {
        (0..<count).map { index in
            let url = URL(fileURLWithPath: "/tmp/NebbyTagTests/\(prefix)-\(index).txt")
            return FileItem(id: url, url: url, name: url.lastPathComponent,
                            itemKind: .available(.file), contentType: .available(.plainText),
                            kindDescription: .available("Text"), byteSize: .available(1),
                            creationDate: .available(Date(timeIntervalSince1970: 0)),
                            modificationDate: .available(Date(timeIntervalSince1970: 0)),
                            imageDimensions: .notApplicable, systemIcon: .init(fileURL: url))
        }
    }
}
