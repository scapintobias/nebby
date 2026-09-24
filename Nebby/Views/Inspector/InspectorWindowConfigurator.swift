import AppKit
import SwiftUI

/// SwiftUI's defaultSize can be superseded by a previously restored window frame.
/// Apply the compact starting size once per native window, leaving later user resizes alone.
struct InspectorWindowConfigurator: NSViewRepresentable {
    let itemsExpanded: Bool

    static func setItemsExpanded(_ expanded: Bool) {
        guard let window = NSApp.keyWindow else { return }
        InspectorWindowSizing.configure(window, itemsExpanded: expanded)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            InspectorWindowSizing.configure(window, itemsExpanded: itemsExpanded)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            InspectorWindowSizing.configure(window, itemsExpanded: itemsExpanded)
        }
    }
}

@MainActor
private enum InspectorWindowSizing {
    private struct WindowState {
        var expanded: Bool
        var compactWidth: CGFloat
        var compactHeight: CGFloat
    }
    private static var states: [Int: WindowState] = [:]

    static func configure(_ window: NSWindow, itemsExpanded: Bool) {
        let key = window.windowNumber
        if states[key] == nil {
            window.contentMinSize = NSSize(width: 340, height: 320)
            window.setContentSize(NSSize(width: 390, height: 510))
            states[key] = WindowState(expanded: false, compactWidth: 390, compactHeight: 510)
        }
        guard var state = states[key] else { return }
        guard state.expanded != itemsExpanded else { return }
        if itemsExpanded {
            state.compactWidth = window.contentView?.bounds.width ?? 390
            state.compactHeight = window.contentView?.bounds.height ?? 510
            let availableHeight = window.screen?.visibleFrame.height ?? 840
            resize(window, width: max(state.compactWidth, 820),
                   height: max(state.compactHeight, min(840, availableHeight - 20)))
        } else {
            resize(window, width: state.compactWidth, height: state.compactHeight)
        }
        state.expanded = itemsExpanded
        states[key] = state
    }

    private static func resize(_ window: NSWindow, width: CGFloat, height: CGFloat) {
        let frame = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: width, height: height))
        var next = window.frame
        next.origin.y += next.height - frame.height
        next.size = frame.size
        window.setFrame(next, display: true, animate: true)
    }
}
