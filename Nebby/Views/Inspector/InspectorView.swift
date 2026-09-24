import SwiftUI

struct InspectorView: View {
    let count: Int
    let items: [FileItem]
    let scope: InspectionScope
    let tagState: PrototypeTagState
    let toggleTag: (PrototypeTag) -> Void
    let bulkOperation: PrototypeBulkOperationState
    let startBulkOperation: () -> Void
    let retryBulkOperation: () -> Void
    let dismissBulkOperation: () -> Void
    @Binding var tableSelection: Set<FileItem.ID>
    let aggregate: AggregateSelection?
    let restoreAll: () -> Void
    let open: () -> Void
    @State private var generalExpanded = true
    @State private var tagsExpanded = false
    @State private var permissionsExpanded = false
    @State private var itemsExpanded = false

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 25, weight: .light))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(count) \(count == 1 ? "Item" : "Items")")
                            .font(.headline)
                        Text(count == 1 ? "Selection" : "Multiple Selection")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button("Open…", action: open)
                        .controlSize(.small)
                        .accessibilityLabel("Open files or folders")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if let aggregate {
                    let presentation = InspectorPresentation(aggregate: aggregate)
                    Text(presentation.signature)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.quaternary.opacity(0.25))
                        .accessibilityLabel("Selection summary: \(presentation.signature)")

                    if scope.isNarrower(than: items) {
                        InspectionScopeBar(items: scope.items(in: items), parentCount: count,
                                           restoreAll: restoreAll)
                    }

                    DisclosureGroup(isExpanded: $generalExpanded) {
                        GeneralMetadataView(presentation: presentation)
                            .padding(.leading, 18)
                            .padding(.trailing, 16)
                            .padding(.bottom, 10)
                    } label: {
                        sectionLabel("General")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                } else {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Reading metadata…").foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .padding(16)
                    .accessibilityElement(children: .combine)
                }

                Divider()
                DisclosureGroup(isExpanded: $tagsExpanded) {
                    TagsSectionView(items: scope.items(in: items), state: tagState, toggle: toggleTag)
                        .padding(.leading, 18)
                        .padding(.trailing, 16)
                        .padding(.bottom, 10)
                } label: {
                    sectionLabel("Tags")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                collapsedSection("Open With")
                collapsedSection("Comments")
                Divider()
                DisclosureGroup(isExpanded: $itemsExpanded) {
                    ItemsTableView(items: items, selection: $tableSelection)
                        .frame(height: 250)
                        .padding(.bottom, 8)
                } label: {
                    sectionLabel("Items (\(count))")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                Divider()
                DisclosureGroup(isExpanded: $permissionsExpanded) {
                    PermissionsDemoSectionView(state: bulkOperation, start: {
                        tagsExpanded = false
                        itemsExpanded = false
                        startBulkOperation()
                    }, retry: retryBulkOperation, dismiss: dismissBulkOperation)
                        .padding(.leading, 18)
                        .padding(.trailing, 16)
                        .padding(.bottom, 10)
                } label: {
                    sectionLabel("Sharing & Permissions")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .id("permissions")
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .onChange(of: bulkOperation.reportVisible) { _, visible in
                if visible {
                    withAnimation(.easeOut(duration: 0.2)) {
                        scrollProxy.scrollTo("permissions", anchor: .bottom)
                    }
                }
            }
        }
        .frame(minWidth: 340, idealWidth: 390, minHeight: 320, idealHeight: 510)
        .background(InspectorWindowConfigurator(itemsExpanded: itemsExpanded))
        .onChange(of: itemsExpanded) { _, expanded in
            InspectorWindowConfigurator.setItemsExpanded(expanded)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.primary)
    }

    private func collapsedSection(_ title: String) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                sectionLabel(title)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title), collapsed")
        }
    }
}

private struct GeneralMetadataView: View {
    let presentation: InspectorPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            row("Kind", presentation.kinds)
            row("Size", presentation.size)
            row("Location", presentation.location)
            row("Created", presentation.created)
            row("Modified", presentation.modified)
            ForEach(Array(presentation.dimensions.enumerated()), id: \.offset) { index, value in
                row(index == 0 ? "Dimensions" : "", value)
            }
        }
    }

    private func row(_ title: String, _ value: InspectorPresentation.Value) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(value.text)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
                if let detail = value.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title.isEmpty ? "Dimensions" : title): \(value.text)\(value.detail.map { ", \($0)" } ?? "")")
    }
}
