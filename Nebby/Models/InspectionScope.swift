import Foundation

/// Local inspection inside Nebby. ParentSelection remains the independent input owner.
struct InspectionScope: Equatable {
    private(set) var state: State = .all

    enum State: Equatable {
        case all
        case subset(Set<FileItem.ID>)
    }

    var selectedIDs: Set<FileItem.ID> {
        if case let .subset(ids) = state { return ids }
        return []
    }

    func items(in parentItems: [FileItem]) -> [FileItem] {
        switch state {
        case .all: return parentItems
        case let .subset(ids): return parentItems.filter { ids.contains($0.id) }
        }
    }

    func isNarrower(than parentItems: [FileItem]) -> Bool {
        items(in: parentItems).count < parentItems.count
    }

    mutating func select(_ ids: Set<FileItem.ID>, within parentItems: [FileItem]) {
        let valid = ids.intersection(Set(parentItems.map(\.id)))
        // An empty native table selection means inspect the full parent selection.
        state = valid.isEmpty ? .all : .subset(valid)
    }

    mutating func restoreAll() { state = .all }

    mutating func parentWasReplaced() { state = .all }
}
