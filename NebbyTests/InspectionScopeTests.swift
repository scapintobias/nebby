import Foundation
import UniformTypeIdentifiers
import XCTest
@testable import Nebby

final class InspectionScopeTests: XCTestCase {
    private let aggregator = SelectionAggregator()

    func testNewParentDefaultsToAllItems() {
        let parent = fixtures()
        let scope = InspectionScope()
        XCTAssertEqual(scope.state, .all)
        XCTAssertEqual(scope.items(in: parent).map(\.id), parent.map(\.id))
        XCTAssertTrue(scope.selectedIDs.isEmpty)
    }

    func testOneItemScopeKeepsStableIdentity() {
        let parent = fixtures()
        var scope = InspectionScope()
        scope.select([parent[1].id], within: parent)
        XCTAssertEqual(scope.selectedIDs, [parent[1].id])
        XCTAssertEqual(scope.items(in: parent).map(\.id), [parent[1].id])
        XCTAssertTrue(scope.isNarrower(than: parent))
    }

    func testMultipleItemsRetainParentOrderRegardlessOfSelectionOrder() {
        let parent = fixtures()
        var scope = InspectionScope()
        scope.select([parent[2].id, parent[0].id], within: parent)
        XCTAssertEqual(scope.items(in: parent).map(\.id), [parent[0].id, parent[2].id])
    }

    func testRestoreAllClearsVisualSelectionAndRestoresFullScope() {
        let parent = fixtures()
        var scope = InspectionScope()
        scope.select([parent[0].id], within: parent)
        scope.restoreAll()
        XCTAssertEqual(scope.state, .all)
        XCTAssertTrue(scope.selectedIDs.isEmpty)
        XCTAssertEqual(scope.items(in: parent).count, parent.count)
    }

    func testEmptyLocalSelectionMeansAllParentItems() {
        let parent = fixtures()
        var scope = InspectionScope()
        scope.select([parent[1].id], within: parent)
        scope.select([], within: parent)
        XCTAssertEqual(scope.state, .all)
        XCTAssertEqual(scope.items(in: parent).count, parent.count)
    }

    func testReplacingParentResetsScopeEvenIfNewInputUsesSameURLs() {
        let parent = fixtures()
        var scope = InspectionScope()
        scope.select([parent[1].id], within: parent)
        scope.parentWasReplaced()
        XCTAssertEqual(scope.state, .all)
        XCTAssertTrue(scope.selectedIDs.isEmpty)
    }

    func testStaleIDsCannotPolluteNewParent() {
        let old = fixtures()
        let fresh = [fixture("new.txt", size: 99)]
        var scope = InspectionScope()
        scope.select([old[0].id], within: old)
        scope.parentWasReplaced()
        scope.select([old[0].id], within: fresh)
        XCTAssertEqual(scope.state, .all)
        XCTAssertEqual(scope.items(in: fresh).map(\.id), fresh.map(\.id))
    }

    func testAggregationReceivesExactlyCurrentScopeItems() {
        let parent = fixtures()
        var scope = InspectionScope()
        scope.select([parent[0].id, parent[2].id], within: parent)
        let scoped = scope.items(in: parent)
        XCTAssertEqual(scoped.map(\.id), [parent[0].id, parent[2].id])
        let result = aggregator.aggregate(scoped)
        XCTAssertEqual(result.itemCount, 2)
        XCTAssertEqual(result.size.summary?.knownBytes, 40)
        XCTAssertEqual(result.types.summary?.reduce(0) { $0 + $1.count }, 2)
    }

    func testLocalChangesNeverMutateParentMembershipOrOrder() {
        let parent = fixtures()
        let original = parent.map(\.id)
        var scope = InspectionScope()
        scope.select([parent[2].id], within: parent)
        scope.select([parent[0].id, parent[1].id], within: parent)
        scope.restoreAll()
        XCTAssertEqual(parent.map(\.id), original)
        XCTAssertEqual(scope.items(in: parent).map(\.id), original)
    }

    private func fixtures() -> [FileItem] {
        [fixture("a.txt", size: 10), fixture("b.png", size: 20, type: .png), fixture("c.txt", size: 30)]
    }

    private func fixture(_ name: String, size: Int64, type: UTType = .plainText) -> FileItem {
        let url = URL(fileURLWithPath: "/tmp/NebbyScopeTests/\(name)")
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        return FileItem(
            id: url, url: url, name: name, itemKind: .available(.file),
            contentType: .available(type), kindDescription: .available(type.localizedDescription ?? "File"),
            byteSize: .available(size), creationDate: .available(day), modificationDate: .available(day),
            imageDimensions: .notApplicable, systemIcon: .init(fileURL: url)
        )
    }
}
