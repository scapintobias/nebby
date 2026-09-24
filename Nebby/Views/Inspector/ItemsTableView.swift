import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// AppKit owns desktop row selection, focus, and shared header/body column geometry.
/// SwiftUI owns the selected stable file IDs through the binding.
struct ItemsTableView: NSViewRepresentable {
    let items: [FileItem]
    @Binding var selection: Set<FileItem.ID>

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let table = NSTableView()
        table.delegate = context.coordinator
        table.dataSource = context.coordinator
        table.allowsMultipleSelection = true
        table.allowsEmptySelection = true
        table.selectionHighlightStyle = .regular
        table.rowHeight = 24
        table.columnAutoresizingStyle = .noColumnAutoresizing
        table.usesAlternatingRowBackgroundColors = true
        table.headerView = NSTableHeaderView()

        for (name, width, minimum) in [
            ("Name", 245.0, 140.0), ("Kind", 120.0, 90.0),
            ("Size", 75.0, 65.0), ("Dimensions", 130.0, 115.0),
            ("Modified", 135.0, 110.0)
        ] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(name))
            column.title = name
            column.width = width
            column.minWidth = minimum
            column.resizingMask = .userResizingMask
            table.addTableColumn(column)
        }

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        context.coordinator.table = table
        context.coordinator.items = items
        table.reloadData()
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let table = coordinator.table else { return }
        if coordinator.items.map(\.id) != items.map(\.id) {
            coordinator.items = items
            table.reloadData()
        } else {
            coordinator.items = items
        }
        let desired = IndexSet(items.indices.filter { selection.contains(items[$0].id) })
        if table.selectedRowIndexes != desired {
            coordinator.isApplyingSelection = true
            table.selectRowIndexes(desired, byExtendingSelection: false)
            coordinator.isApplyingSelection = false
        }
    }

    final class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        var parent: ItemsTableView
        var items: [FileItem] = []
        weak var table: NSTableView?
        var isApplyingSelection = false

        init(_ parent: ItemsTableView) { self.parent = parent }

        func numberOfRows(in tableView: NSTableView) -> Int { items.count }

        func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
            guard let column, items.indices.contains(row) else { return nil }
            let item = items[row]
            let key = column.identifier.rawValue
            let view = tableView.makeView(withIdentifier: column.identifier, owner: self) as? NSTableCellView
                ?? makeCell(for: key, identifier: column.identifier)
            view.textField?.stringValue = value(for: key, item: item)
            if key == "Name" {
                view.imageView?.image = NSWorkspace.shared.icon(forFile: item.systemIcon.fileURL.path)
            }
            return view
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isApplyingSelection, let table else { return }
            parent.selection = Set(table.selectedRowIndexes.compactMap { items.indices.contains($0) ? items[$0].id : nil })
            // The scoped SwiftUI metadata update must not strand keyboard focus on the host view.
            DispatchQueue.main.async { [weak table] in
                guard let table, let window = table.window else { return }
                window.makeFirstResponder(table)
            }
        }

        private func makeCell(for key: String, identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
            let cell = NSTableCellView()
            cell.identifier = identifier
            let label = NSTextField(labelWithString: "")
            label.lineBreakMode = key == "Name" ? .byTruncatingMiddle : .byTruncatingTail
            label.maximumNumberOfLines = 1
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(label)
            cell.textField = label
            if key == "Name" {
                let icon = NSImageView()
                icon.imageScaling = .scaleProportionallyDown
                icon.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(icon)
                cell.imageView = icon
                NSLayoutConstraint.activate([
                    icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 5),
                    icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    icon.widthAnchor.constraint(equalToConstant: 16),
                    icon.heightAnchor.constraint(equalToConstant: 16),
                    label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6)
                ])
            } else {
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 5).isActive = true
            }
            NSLayoutConstraint.activate([
                label.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -5),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            return cell
        }

        private func value(for key: String, item: FileItem) -> String {
            switch key {
            case "Name": return item.name
            case "Kind":
                if let description = item.kindDescription.value { return description }
                if let type = item.contentType.value { return type.localizedDescription ?? type.identifier }
                return "Unavailable"
            case "Size":
                switch item.byteSize {
                case .available(let bytes): return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
                case .notApplicable: return "—"
                case .unavailable: return "Unavailable"
                }
            case "Dimensions":
                switch item.imageDimensions {
                case .available(let value): return "\(value.width) × \(value.height)"
                case .notApplicable: return "—"
                case .unavailable: return "Unavailable"
                }
            case "Modified":
                return item.modificationDate.value?.formatted(date: .abbreviated, time: .omitted) ?? "Unavailable"
            default: return ""
            }
        }
    }
}
