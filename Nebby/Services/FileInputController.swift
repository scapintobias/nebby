import AppKit
import UniformTypeIdentifiers

@MainActor
final class FileInputController {
    func openPanel(into selection: ParentSelection) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = false
        panel.prompt = "Open"

        panel.begin { response in
            guard response == .OK else { return }
            Task { @MainActor in
                let revision = selection.beginInput()
                selection.replace(with: panel.urls, for: revision)
            }
        }
    }

    func receiveDrop(_ providers: [NSItemProvider], into selection: ParentSelection) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else { return false }

        let revision = selection.beginInput()
        var loaded = Array<URL?>(repeating: nil, count: fileProviders.count)
        var remaining = fileProviders.count

        for (index, provider) in fileProviders.enumerated() {
            provider.loadObject(ofClass: NSURL.self) { object, _ in
                let url = (object as? NSURL).map { $0 as URL }
                Task { @MainActor in
                    loaded[index] = url
                    remaining -= 1
                    if remaining == 0 {
                        selection.replace(with: loaded.compactMap { $0 }, for: revision)
                    }
                }
            }
        }

        return true
    }
}
