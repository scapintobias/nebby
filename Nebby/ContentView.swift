import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var selection: ParentSelection
    @State private var isDropTargeted = false
    @State private var inspectionScope = InspectionScope()
    @State private var prototypeTags = PrototypeTagState()
    @State private var bulkOperation = PrototypeBulkOperationState()
    private let input = FileInputController()
    private let aggregator = SelectionAggregator()
    private let bulkController = PrototypeBulkOperationController()

    var body: some View {
        Group {
            if selection.urls.isEmpty {
                VStack(spacing: 14) {
                    FileDropView(isTargeted: isDropTargeted)
                    Button("Open…") { input.openPanel(into: selection) }
                        .accessibilityLabel("Open files or folders")
                }
                .padding(20)
            } else {
                InspectorView(
                    count: selection.urls.count,
                    items: selection.items,
                    scope: inspectionScope,
                    tagState: prototypeTags,
                    toggleTag: { tag in
                        prototypeTags.toggle(tag, in: inspectionScope.items(in: selection.items))
                    },
                    bulkOperation: bulkOperation,
                    startBulkOperation: {
                        bulkController.start(on: inspectionScope.items(in: selection.items), state: &bulkOperation)
                    },
                    retryBulkOperation: { bulkController.retry(state: &bulkOperation) },
                    dismissBulkOperation: { bulkOperation.dismiss() },
                    tableSelection: Binding(
                        get: { inspectionScope.selectedIDs },
                        set: { inspectionScope.select($0, within: selection.items) }
                    ),
                    aggregate: selection.isLoadingMetadata ? nil :
                        aggregator.aggregate(inspectionScope.items(in: selection.items)),
                    restoreAll: { inspectionScope.restoreAll() },
                    open: { input.openPanel(into: selection) }
                )
            }
        }
        .frame(minWidth: 340, minHeight: 320)
        .navigationTitle(selection.urls.isEmpty ? "Nebby" :
            "\(selection.urls.count) \(selection.urls.count == 1 ? "Item" : "Items")")
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            input.receiveDrop(providers, into: selection)
        }
        .onChange(of: selection.selectionRevision) { _, _ in
            inspectionScope.parentWasReplaced()
            prototypeTags.reset(for: [])
            bulkOperation.reset()
        }
        .onChange(of: selection.items.map(\.id)) { _, _ in
            prototypeTags.reset(for: selection.items)
        }
    }
}

#Preview {
    ContentView(selection: ParentSelection())
}
