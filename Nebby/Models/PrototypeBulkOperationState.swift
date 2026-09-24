import Foundation

/// A deterministic, file-system-free bulk-operation result for the portfolio demo.
struct PrototypeBulkOperationState {
    struct Failure: Equatable, Identifiable {
        let id: FileItem.ID
        let name: String
        let reason: String
    }

    private(set) var targetedIDs: [FileItem.ID] = []
    private(set) var updatedIDs: Set<FileItem.ID> = []
    private(set) var failures: [Failure] = []
    private(set) var attemptedIDs: [[FileItem.ID]] = []
    private(set) var reportVisible = false

    var hasOperation: Bool { !targetedIDs.isEmpty }
    var successCount: Int { updatedIDs.count }
    var failureCount: Int { failures.count }

    mutating func start(items: [FileItem], failingIDs: Set<FileItem.ID>) {
        reset()
        guard !items.isEmpty else { return }
        targetedIDs = items.map(\.id)
        attemptedIDs = [targetedIDs]
        updatedIDs = Set(targetedIDs).subtracting(failingIDs)
        failures = items.filter { failingIDs.contains($0.id) }.enumerated().map { index, item in
            Failure(id: item.id, name: item.name,
                    reason: index == 2 ? "File is locked" : "Permission denied")
        }
        reportVisible = !failures.isEmpty
    }

    /// Only unresolved IDs enter this attempt. All earlier successes stay recorded.
    mutating func retry(stillFailingIDs: Set<FileItem.ID>) {
        guard !failures.isEmpty else { return }
        let unresolved = failures
        attemptedIDs.append(unresolved.map(\.id))
        let remaining = stillFailingIDs.intersection(Set(unresolved.map(\.id)))
        updatedIDs.formUnion(unresolved.map(\.id).filter { !remaining.contains($0) })
        failures = unresolved.filter { remaining.contains($0.id) }
        reportVisible = !failures.isEmpty
    }

    mutating func dismiss() { reportVisible = false }

    mutating func reset() {
        targetedIDs = []
        updatedIDs = []
        failures = []
        attemptedIDs = []
        reportVisible = false
    }
}
