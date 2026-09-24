import Foundation

/// Fixture policy: three failures for a 17-item run; the first retry leaves one,
/// the second resolves it. No resource values or permissions are written.
struct PrototypeBulkOperationController {
    func start(on items: [FileItem], state: inout PrototypeBulkOperationState) {
        let failures = Set(items.suffix(min(3, items.count)).map(\.id))
        state.start(items: items, failingIDs: failures)
    }

    func retry(state: inout PrototypeBulkOperationState) {
        let remaining: Set<FileItem.ID> = state.attemptedIDs.count == 1
            ? Set(state.failures.suffix(1).map(\.id)) : []
        state.retry(stillFailingIDs: remaining)
    }
}
