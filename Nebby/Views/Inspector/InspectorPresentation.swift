import Foundation
import UniformTypeIdentifiers

/// Formatting only. Collection meaning and coverage come from SelectionAggregator.
struct InspectorPresentation {
    struct Value {
        let text: String
        let detail: String?
    }

    let aggregate: AggregateSelection

    var signature: String {
        var parts: [String] = []
        let size = self.size
        if size.text != "Unavailable" && size.text != "Not applicable" {
            parts.append(size.text + (size.detail.map { " · \($0)" } ?? ""))
        }
        if let types = aggregate.types.summary {
            parts += types.prefix(3).map { "\($0.count) \(typeName($0.identifier))" }
            if types.count > 3 { parts.append("\(types.count - 3) more types") }
        }
        parts += classificationExtras
        if aggregate.types.coverage.availableCount < aggregate.itemCount {
            parts.append("type known for \(aggregate.types.coverage.availableCount) of \(aggregate.itemCount)")
        }
        return parts.isEmpty ? "Metadata unavailable" : parts.joined(separator: " · ")
    }

    var size: Value {
        let field = aggregate.size
        guard let summary = field.summary else { return missing(field.coverage) }
        if summary.overflowed { return Value(text: "Too large to total", detail: coverage(field.coverage)) }
        guard let bytes = summary.knownBytes else { return missing(field.coverage) }
        let formatted = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        return Value(text: field.coverage.isComplete ? formatted : "\(formatted) known", detail: coverage(field.coverage))
    }

    var location: Value {
        switch aggregate.location.summary {
        case let .shared(url):
            return Value(text: url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent,
                         detail: url.path)
        case .mixed: return Value(text: "Mixed", detail: nil)
        case nil: return missing(aggregate.location.coverage)
        }
    }

    var created: Value { date(aggregate.creationDate) }
    var modified: Value { date(aggregate.modificationDate) }

    var dimensions: [Value] {
        let field = aggregate.dimensions
        guard let range = field.summary else { return [missing(field.coverage)] }
        let detail = coverage(field.coverage)
        if range.minimumWidth == range.maximumWidth && range.minimumHeight == range.maximumHeight {
            return [Value(text: "\(range.minimumWidth) × \(range.minimumHeight) px", detail: detail)]
        }
        func span(_ low: Int, _ high: Int) -> String {
            low == high ? "\(low) px" : "\(low)–\(high) px"
        }
        return [Value(text: "Width \(span(range.minimumWidth, range.maximumWidth))", detail: nil),
                Value(text: "Height \(span(range.minimumHeight, range.maximumHeight))", detail: detail)]
    }

    var kinds: Value {
        guard let types = aggregate.types.summary, !types.isEmpty else { return missing(aggregate.types.coverage) }
        let details = [coverage(aggregate.types.coverage), classificationExtras.joined(separator: " · ")]
            .compactMap { $0 }.filter { !$0.isEmpty }
        let title = aggregate.itemCount == 1 && types.count == 1
            ? typeName(types[0].identifier)
            : types.map { "\(typeName($0.identifier)) · \($0.count)" }.joined(separator: "  ·  ")
        return Value(text: title,
                     detail: details.isEmpty ? nil : details.joined(separator: " · "))
    }

    private func date(_ field: AggregateField<InclusiveRange<Date>>) -> Value {
        guard let summary = field.summary else { return missing(field.coverage) }
        let formatted: String
        switch summary {
        case let .single(value): formatted = formatDate(value)
        case let .range(first, last):
            // Preserve a visible difference when two instants fall in the same displayed minute.
            let precise = formatDate(first) == formatDate(last)
            formatted = "\(formatDate(first, precise: precise)) – \(formatDate(last, precise: precise))"
        }
        return Value(text: formatted, detail: coverage(field.coverage))
    }

    private func formatDate(_ date: Date, precise: Bool = false) -> String {
        date.formatted(date: .abbreviated, time: precise ? .standard : .shortened)
    }

    private func typeName(_ identifier: String) -> String {
        UTType(identifier)?.localizedDescription ?? identifier
    }

    private var classificationExtras: [String] {
        aggregate.classifications.summary?.compactMap { count in
            switch count.kind {
            case .symbolicLink:
                let typedLinks = aggregate.types.summary?
                    .first(where: { $0.identifier == UTType.symbolicLink.identifier })?.count ?? 0
                let remaining = max(0, count.count - typedLinks)
                return remaining == 0 ? nil : "\(remaining) symbolic \(remaining == 1 ? "link" : "links")"
            case .other: return "\(count.count) other \(count.count == 1 ? "item" : "items")"
            case .file, .folder: return nil
            }
        } ?? []
    }

    private func missing(_ counts: AggregateCoverage) -> Value {
        if counts.itemCount > 0 && counts.notApplicableCount == counts.itemCount {
            return Value(text: "Not applicable", detail: nil)
        }
        return Value(text: "Unavailable", detail: coverage(counts))
    }

    private func coverage(_ counts: AggregateCoverage) -> String? {
        guard !counts.isComplete else { return nil }
        if counts.availableCount == 0 && counts.notApplicableCount == counts.itemCount { return nil }
        var parts: [String] = []
        if counts.unknownApplicabilityCount > 0 {
            parts.append("\(counts.applicableCount) applicable · \(counts.unknownApplicabilityCount) unknown")
        } else if counts.notApplicableCount > 0 {
            parts.append("Applies to \(counts.applicableCount) of \(counts.itemCount) items")
        }
        if counts.availableCount < counts.applicableCount {
            parts.append("\(counts.availableCount) of \(counts.applicableCount) values available")
        }
        return parts.isEmpty ? "\(counts.availableCount) of \(counts.itemCount) values available" : parts.joined(separator: " · ")
    }
}
