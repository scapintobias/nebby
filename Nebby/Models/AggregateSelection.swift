import Foundation

/// Counts describe the original scope, including values that could not be read.
struct AggregateCoverage: Equatable, Sendable {
    let itemCount: Int
    let applicableCount: Int
    let availableCount: Int
    let unavailableCount: Int
    let notApplicableCount: Int
    let unknownApplicabilityCount: Int

    var isComplete: Bool {
        availableCount == itemCount && itemCount > 0
    }
}

struct AggregateField<Summary: Sendable>: Sendable {
    let summary: Summary?
    let coverage: AggregateCoverage
}

extension AggregateField: Equatable where Summary: Equatable {}

enum SharedOrMixed<Value: Sendable>: Sendable {
    case shared(Value)
    case mixed
}

extension SharedOrMixed: Equatable where Value: Equatable {}

enum InclusiveRange<Value: Sendable>: Sendable {
    case single(Value)
    case range(minimum: Value, maximum: Value)
}

extension InclusiveRange: Equatable where Value: Equatable {}

struct DimensionRange: Equatable, Sendable {
    let minimumWidth: Int
    let maximumWidth: Int
    let minimumHeight: Int
    let maximumHeight: Int
}

struct TypeCount: Equatable, Sendable {
    let identifier: String
    let count: Int
}

struct KindCount: Equatable, Sendable {
    let kind: FileItem.ItemKind
    let count: Int
}

struct ByteTotal: Equatable, Sendable {
    /// Nil only when no sizes are available or the sum exceeded Int64.
    let knownBytes: Int64?
    let overflowed: Bool
}

struct AggregateSelection: Sendable {
    let itemCount: Int
    let types: AggregateField<[TypeCount]>
    let classifications: AggregateField<[KindCount]>
    let size: AggregateField<ByteTotal>
    let creationDate: AggregateField<InclusiveRange<Date>>
    let modificationDate: AggregateField<InclusiveRange<Date>>
    let dimensions: AggregateField<DimensionRange>
    let location: AggregateField<SharedOrMixed<URL>>
}
