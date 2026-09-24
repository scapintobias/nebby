import SwiftUI

struct InspectionScopeBar: View {
    let items: [FileItem]
    let parentCount: Int
    let restoreAll: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("All \(parentCount) Items", action: restoreAll)
                .buttonStyle(.link)
                .accessibilityLabel("Inspect all \(parentCount) items")
        }
        .font(.caption)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
    }

    private var label: String {
        let prefix = "Inspecting \(items.count) of \(parentCount)"
        guard items.count == 1, let item = items.first else { return prefix }
        return "\(prefix) · \(item.name)"
    }
}
