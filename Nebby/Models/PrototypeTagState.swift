import Foundation

/// In-memory portfolio data. FileItem remains a factual, immutable filesystem snapshot.
enum PrototypeTag: String, CaseIterable, Hashable {
    case travel = "Travel"
    case favorites = "Favorites"
    case portfolio = "Portfolio"
}

struct PrototypeTagCoverage: Equatable {
    let present: Int
    let total: Int

    enum State: Equatable { case checked, mixed, unchecked }

    var state: State {
        if present == 0 { return .unchecked }
        if present == total { return .checked }
        return .mixed
    }
}

struct PrototypeTagState {
    private(set) var parentIDs: [FileItem.ID] = []
    private(set) var membership: [FileItem.ID: Set<PrototypeTag>] = [:]

    mutating func reset(for items: [FileItem]) {
        parentIDs = items.map(\.id)
        membership = [:]
        for (index, item) in items.enumerated() {
            var tags: Set<PrototypeTag> = [.travel]
            if index < min(5, items.count) { tags.insert(.favorites) }
            membership[item.id] = tags
        }
    }

    func coverage(of tag: PrototypeTag, in items: [FileItem]) -> PrototypeTagCoverage {
        PrototypeTagCoverage(
            present: items.reduce(0) { $0 + (membership[$1.id]?.contains(tag) == true ? 1 : 0) },
            total: items.count
        )
    }

    mutating func set(_ tag: PrototypeTag, present: Bool, in items: [FileItem]) {
        for item in items where membership[item.id] != nil {
            if present { membership[item.id]?.insert(tag) }
            else { membership[item.id]?.remove(tag) }
        }
    }

    /// Clicking a mixed or unchecked control resolves it to checked; checked removes it.
    mutating func toggle(_ tag: PrototypeTag, in items: [FileItem]) {
        set(tag, present: coverage(of: tag, in: items).state != .checked, in: items)
    }
}
