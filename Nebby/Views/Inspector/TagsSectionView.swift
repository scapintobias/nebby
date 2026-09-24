import AppKit
import SwiftUI

struct TagsSectionView: View {
    let items: [FileItem]
    let state: PrototypeTagState
    let toggle: (PrototypeTag) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(PrototypeTag.allCases, id: \.self) { tag in
                let coverage = state.coverage(of: tag, in: items)
                HStack(spacing: 8) {
                    NativeTagCheckbox(title: tag.rawValue, state: coverage.state) {
                        toggle(tag)
                    }
                    Spacer(minLength: 12)
                    Text("\(coverage.present) of \(coverage.total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            Text("Demo tags · files are unchanged")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 3)
        }
    }
}

private struct NativeTagCheckbox: NSViewRepresentable {
    let title: String
    let state: PrototypeTagCoverage.State
    let action: () -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: context.coordinator,
                              action: #selector(Coordinator.clicked))
        button.allowsMixedState = true
        button.setAccessibilityLabel(title)
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.action = action
        button.title = title
        button.state = switch state {
        case .checked: .on
        case .mixed: .mixed
        case .unchecked: .off
        }
        let accessibilityValue = switch state {
        case .checked: "Checked"
        case .mixed: "Mixed"
        case .unchecked: "Unchecked"
        }
        button.setAccessibilityValue(accessibilityValue)
    }

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func clicked() { action() }
    }
}
