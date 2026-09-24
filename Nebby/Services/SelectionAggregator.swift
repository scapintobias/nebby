import Foundation
import UniformTypeIdentifiers

/// Pure aggregation over any ordered inspection scope. The input is never changed.
struct SelectionAggregator: Sendable {
    func aggregate(_ items: [FileItem]) -> AggregateSelection {
        AggregateSelection(
            itemCount: items.count,
            types: distribution(items.map(\.contentType), key: { $0.identifier }, make: TypeCount.init),
            classifications: classification(items),
            size: size(items),
            creationDate: dates(items.map(\.creationDate)),
            modificationDate: dates(items.map(\.modificationDate)),
            dimensions: dimensions(items),
            location: location(items)
        )
    }

    private func distribution<Key: Hashable & Comparable, Value: Sendable, Count: Sendable>(
        _ values: [MetadataValue<Value>],
        key: (Value) -> Key,
        make: (Key, Int) -> Count
    ) -> AggregateField<[Count]> {
        let coverage = coverage(values)
        var counts: [Key: Int] = [:]
        for value in values {
            if case let .available(actual) = value { counts[key(actual), default: 0] += 1 }
        }
        let sortedCounts = counts.sorted { $0.key < $1.key }.map { make($0.key, $0.value) }
        return .init(summary: sortedCounts.isEmpty ? nil : sortedCounts, coverage: coverage)
    }

    private func classification(_ items: [FileItem]) -> AggregateField<[KindCount]> {
        let values = items.map(\.itemKind)
        let coverage = coverage(values)
        let order: [FileItem.ItemKind] = [.file, .folder, .symbolicLink, .other]
        let counts = order.compactMap { kind -> KindCount? in
            let count = values.filter { $0.value == kind }.count
            return count == 0 ? nil : KindCount(kind: kind, count: count)
        }
        return .init(summary: counts.isEmpty ? nil : counts, coverage: coverage)
    }

    private func size(_ items: [FileItem]) -> AggregateField<ByteTotal> {
        let values = items.map(\.byteSize)
        let coverage = coverage(values, unknownApplicability: items.map { $0.itemKind.value == nil })
        var total: Int64 = 0
        var overflowed = false
        for value in values {
            guard case let .available(bytes) = value else { continue }
            let (next, overflow) = total.addingReportingOverflow(bytes)
            overflowed = overflowed || overflow
            if !overflowed { total = next }
        }
        return .init(
            summary: coverage.availableCount == 0 ? nil : ByteTotal(
                knownBytes: overflowed ? nil : total,
                overflowed: overflowed
            ),
            coverage: coverage
        )
    }

    private func dates(_ values: [MetadataValue<Date>]) -> AggregateField<InclusiveRange<Date>> {
        let coverage = coverage(values)
        let available = values.compactMap(\.value)
        guard let earliest = available.min(), let latest = available.max() else {
            return .init(summary: nil, coverage: coverage)
        }
        return .init(
            summary: earliest == latest ? .single(earliest) : .range(minimum: earliest, maximum: latest),
            coverage: coverage
        )
    }

    private func dimensions(_ items: [FileItem]) -> AggregateField<DimensionRange> {
        let values = items.map(\.imageDimensions)
        let unknown = items.map { item in
            if case .unavailable = item.imageDimensions {
                return item.contentType.value == nil
            }
            return false
        }
        let coverage = coverage(values, unknownApplicability: unknown)
        let available = values.compactMap(\.value)
        guard let first = available.first else { return .init(summary: nil, coverage: coverage) }
        let range = available.dropFirst().reduce(
            DimensionRange(
                minimumWidth: first.width, maximumWidth: first.width,
                minimumHeight: first.height, maximumHeight: first.height
            )
        ) { range, next in
            DimensionRange(
                minimumWidth: min(range.minimumWidth, next.width),
                maximumWidth: max(range.maximumWidth, next.width),
                minimumHeight: min(range.minimumHeight, next.height),
                maximumHeight: max(range.maximumHeight, next.height)
            )
        }
        return .init(summary: range, coverage: coverage)
    }

    private func location(_ items: [FileItem]) -> AggregateField<SharedOrMixed<URL>> {
        let parents = items.map { $0.url.standardizedFileURL.deletingLastPathComponent() }
        let coverage = AggregateCoverage(
            itemCount: items.count, applicableCount: items.count, availableCount: items.count,
            unavailableCount: 0, notApplicableCount: 0, unknownApplicabilityCount: 0
        )
        guard let first = parents.first else { return .init(summary: nil, coverage: coverage) }
        return .init(
            summary: parents.allSatisfy { $0 == first } ? .shared(first) : .mixed,
            coverage: coverage
        )
    }

    private func coverage<Value: Sendable>(
        _ values: [MetadataValue<Value>],
        unknownApplicability: [Bool]? = nil
    ) -> AggregateCoverage {
        var available = 0
        var unavailable = 0
        var notApplicable = 0
        var unknown = 0
        for (index, value) in values.enumerated() {
            switch value {
            case .available: available += 1
            case .notApplicable: notApplicable += 1
            case .unavailable:
                if unknownApplicability?[index] == true { unknown += 1 }
                else { unavailable += 1 }
            }
        }
        return .init(
            itemCount: values.count,
            applicableCount: available + unavailable,
            availableCount: available,
            unavailableCount: unavailable,
            notApplicableCount: notApplicable,
            unknownApplicabilityCount: unknown
        )
    }
}
