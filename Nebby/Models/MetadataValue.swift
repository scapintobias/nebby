import Foundation

enum MetadataValue<Value: Sendable>: Sendable {
    case available(Value)
    case unavailable(MetadataIssue)
    case notApplicable

    nonisolated var value: Value? {
        guard case let .available(value) = self else { return nil }
        return value
    }
}

extension MetadataValue: Equatable where Value: Equatable {}

struct MetadataIssue: Equatable, Sendable {
    enum Code: String, Sendable {
        case missing
        case readFailed
        case unsupported
    }

    let code: Code
    let detail: String
}
