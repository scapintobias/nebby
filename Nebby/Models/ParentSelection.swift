import Combine
import Foundation

@MainActor
final class ParentSelection: ObservableObject {
    @Published private(set) var urls: [URL] = []
    @Published private(set) var items: [FileItem] = []
    @Published private(set) var isLoadingMetadata = false
    @Published private(set) var selectionRevision = 0
    private var inputRevision = 0
    private var metadataTask: Task<Void, Never>?

    func beginInput() -> Int {
        inputRevision += 1
        return inputRevision
    }

    func replace(with candidates: [URL], for revision: Int) {
        guard revision == inputRevision else { return }

        var seen = Set<URL>()
        let accepted = candidates.compactMap { candidate -> URL? in
            guard candidate.isFileURL else { return nil }
            let url = candidate.standardizedFileURL
            guard FileManager.default.fileExists(atPath: url.path), seen.insert(url).inserted else {
                return nil
            }
            return url
        }

        // Invalid input never destroys the previous parent selection.
        guard !accepted.isEmpty else { return }
        urls = accepted
        items = []
        isLoadingMetadata = true
        selectionRevision += 1

        metadataTask?.cancel()
        let reader = FileMetadataReader()
        metadataTask = Task.detached(priority: .userInitiated) { [weak self] in
            let records = accepted.map(reader.read)
            guard !Task.isCancelled else { return }
            await self?.finishMetadataLoad(records, for: revision)
        }
    }

    private func finishMetadataLoad(_ records: [FileItem], for revision: Int) {
        guard revision == inputRevision else { return }
        items = records
        isLoadingMetadata = false
    }
}
