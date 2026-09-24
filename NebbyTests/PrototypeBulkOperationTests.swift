import Foundation
import UniformTypeIdentifiers
import XCTest
@testable import Nebby

final class PrototypeBulkOperationTests: XCTestCase {
    func testAllSuccess() {
        let items = fixtures(3)
        var state = PrototypeBulkOperationState()
        state.start(items: items, failingIDs: [])
        XCTAssertEqual(state.successCount, 3)
        XCTAssertEqual(state.failureCount, 0)
        XCTAssertFalse(state.reportVisible)
    }

    func testDeterministicPartialSuccessAndOnlyUnresolvedListed() {
        let items = fixtures(17)
        var state = PrototypeBulkOperationState()
        PrototypeBulkOperationController().start(on: items, state: &state)
        XCTAssertEqual(state.successCount, 14)
        XCTAssertEqual(state.failureCount, 3)
        XCTAssertEqual(state.failures.map(\.name), items.suffix(3).map(\.name))
        XCTAssertEqual(state.failures.map(\.reason), ["Permission denied", "Permission denied", "File is locked"])
        XCTAssertEqual(state.updatedIDs.intersection(Set(state.failures.map(\.id))), [])
    }

    func testAllFailure() {
        let items = fixtures(3)
        var state = PrototypeBulkOperationState()
        state.start(items: items, failingIDs: Set(items.map(\.id)))
        XCTAssertEqual(state.successCount, 0)
        XCTAssertEqual(state.failureCount, 3)
        XCTAssertTrue(state.reportVisible)
    }

    func testRetryTargetsOnlyFailuresAndCanReduceThenClearThem() {
        let items = fixtures(17)
        let controller = PrototypeBulkOperationController()
        var state = PrototypeBulkOperationState()
        controller.start(on: items, state: &state)
        let initialSuccesses = state.updatedIDs
        let initialFailures = state.failures.map(\.id)
        controller.retry(state: &state)
        XCTAssertEqual(state.attemptedIDs[1], initialFailures)
        XCTAssertEqual(state.successCount, 16)
        XCTAssertEqual(state.failureCount, 1)
        XCTAssertTrue(initialSuccesses.isSubset(of: state.updatedIDs))
        XCTAssertTrue(state.reportVisible)
        controller.retry(state: &state)
        XCTAssertEqual(state.attemptedIDs[2], [initialFailures[2]])
        XCTAssertEqual(state.successCount, 17)
        XCTAssertEqual(state.failureCount, 0)
        XCTAssertFalse(state.reportVisible)
        XCTAssertEqual(state.attemptedIDs.count, 3)
    }

    func testDismissKeepsSuccessesAndUnresolvedItems() {
        var state = PrototypeBulkOperationState()
        PrototypeBulkOperationController().start(on: fixtures(17), state: &state)
        state.dismiss()
        XCTAssertFalse(state.reportVisible)
        XCTAssertEqual(state.successCount, 14)
        XCTAssertEqual(state.failureCount, 3)
    }

    func testRetryNeverReplaysPriorSuccessesEvenWithRepeatedFailure() {
        let items = fixtures(4)
        var state = PrototypeBulkOperationState()
        state.start(items: items, failingIDs: [items[3].id])
        state.retry(stillFailingIDs: [items[3].id])
        XCTAssertEqual(state.attemptedIDs[1], [items[3].id])
        XCTAssertEqual(state.successCount, 3)
        XCTAssertEqual(state.failureCount, 1)
        state.retry(stillFailingIDs: [])
        XCTAssertEqual(state.attemptedIDs[2], [items[3].id])
        XCTAssertEqual(state.successCount, 4)
    }

    func testParentReplacementClearsStaleOperationAndScopeIsIndependent() {
        let parent = fixtures(17)
        let originalIDs = parent.map(\.id)
        var scope = InspectionScope()
        scope.select(Set(parent.prefix(4).map(\.id)), within: parent)
        let oldScope = scope
        var state = PrototypeBulkOperationState()
        PrototypeBulkOperationController().start(on: scope.items(in: parent), state: &state)
        XCTAssertEqual(parent.map(\.id), originalIDs)
        XCTAssertEqual(scope, oldScope)
        state.reset()
        scope.parentWasReplaced()
        XCTAssertFalse(state.hasOperation)
        XCTAssertTrue(state.updatedIDs.isEmpty)
        XCTAssertTrue(state.failures.isEmpty)
        XCTAssertEqual(scope.state, .all)
    }

    private func fixtures(_ count: Int) -> [FileItem] {
        (0..<count).map { index in
            let url = URL(fileURLWithPath: "/tmp/NebbyBulkTests/file-\(index).txt")
            return FileItem(id: url, url: url, name: url.lastPathComponent,
                            itemKind: .available(.file), contentType: .available(.plainText),
                            kindDescription: .available("Text"), byteSize: .available(1),
                            creationDate: .available(Date(timeIntervalSince1970: 0)),
                            modificationDate: .available(Date(timeIntervalSince1970: 0)),
                            imageDimensions: .notApplicable, systemIcon: .init(fileURL: url))
        }
    }
}
