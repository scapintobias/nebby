import SwiftUI

struct FileDropView: View {
    let isTargeted: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)

            Text("Drop files or folders here")
                .font(.headline)

            Text("Or use Open… to choose several items at once.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 144)
        .background(isTargeted ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        }
        .accessibilityElement(children: .combine)
    }
}
