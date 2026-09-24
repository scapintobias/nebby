import SwiftUI

struct PermissionsDemoSectionView: View {
    let state: PrototypeBulkOperationState
    let start: () -> Void
    let retry: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if state.hasOperation {
                Text("Permissions updated for \(state.successCount) \(state.successCount == 1 ? "file" : "files").")
                    .font(.system(size: 12, weight: .medium))
                if state.reportVisible {
                    failureReport
                }
            }
            Button(state.hasOperation ? "Run demo again" : "Update Permissions (Demo)", action: start)
                .controlSize(.small)
            Text("Controlled demonstration · file permissions are unchanged")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var failureReport: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("\(state.failureCount) \(state.failureCount == 1 ? "file could" : "files could") not be modified.",
                  systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)

            ForEach(state.failures) { failure in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(failure.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(failure.reason)
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 12))
                .accessibilityElement(children: .combine)
            }
            HStack(spacing: 12) {
                Button("Retry", action: retry)
                Button("Dismiss", action: dismiss)
            }
            .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.orange.opacity(0.35)))
        .accessibilityElement(children: .contain)
    }
}
