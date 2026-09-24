import Foundation
import UniformTypeIdentifiers

struct FileMetadataReader: Sendable {
    private let imageReader = ImageMetadataReader()

    nonisolated func read(_ inputURL: URL) -> FileItem {
        let url = inputURL.standardizedFileURL
        let name = url.lastPathComponent
        let icon = FileItem.SystemIconReference(fileURL: url)

        let keys: Set<URLResourceKey> = [
            .nameKey,
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey,
            .contentTypeKey,
            .localizedTypeDescriptionKey,
        ]

        do {
            let values = try url.resourceValues(forKeys: keys)
            let itemKind = Self.itemKind(from: values)
            let contentType: MetadataValue<UTType> = values.contentType.map(MetadataValue.available)
                ?? .unavailable(Self.missing("Uniform type"))
            let kindDescription: MetadataValue<String> = Self.kindDescription(
                resourceDescription: values.localizedTypeDescription,
                contentType: contentType,
                itemKind: itemKind
            )

            let byteSize: MetadataValue<Int64>
            if itemKind.value == .folder {
                byteSize = .notApplicable
            } else if let size = values.fileSize {
                byteSize = .available(Int64(size))
            } else {
                byteSize = .unavailable(Self.missing("Byte size"))
            }

            let creationDate = values.creationDate.map(MetadataValue.available)
                ?? .unavailable(Self.missing("Creation date"))
            let modificationDate = values.contentModificationDate.map(MetadataValue.available)
                ?? .unavailable(Self.missing("Modification date"))

            return FileItem(
                id: url,
                url: url,
                name: values.name ?? name,
                itemKind: itemKind,
                contentType: contentType,
                kindDescription: kindDescription,
                byteSize: byteSize,
                creationDate: creationDate,
                modificationDate: modificationDate,
                imageDimensions: imageReader.dimensions(for: url, contentType: contentType),
                systemIcon: icon
            )
        } catch {
            let issue = MetadataIssue(
                code: .readFailed,
                detail: "Metadata could not be read: \(error.localizedDescription)"
            )

            return FileItem(
                id: url,
                url: url,
                name: name,
                itemKind: .unavailable(issue),
                contentType: .unavailable(issue),
                kindDescription: .unavailable(issue),
                byteSize: .unavailable(issue),
                creationDate: .unavailable(issue),
                modificationDate: .unavailable(issue),
                imageDimensions: .unavailable(issue),
                systemIcon: icon
            )
        }
    }

    nonisolated private static func itemKind(from values: URLResourceValues) -> MetadataValue<FileItem.ItemKind> {
        if values.isSymbolicLink == true { return .available(.symbolicLink) }
        if values.isDirectory == true { return .available(.folder) }
        if values.isRegularFile == true { return .available(.file) }

        if values.isSymbolicLink != nil || values.isDirectory != nil || values.isRegularFile != nil {
            return .available(.other)
        }

        return .unavailable(missing("File or folder status"))
    }

    nonisolated private static func kindDescription(
        resourceDescription: String?,
        contentType: MetadataValue<UTType>,
        itemKind: MetadataValue<FileItem.ItemKind>
    ) -> MetadataValue<String> {
        if let resourceDescription, !resourceDescription.isEmpty {
            return .available(resourceDescription)
        }
        if case let .available(type) = contentType, let description = type.localizedDescription {
            return .available(description)
        }
        if itemKind.value == .folder {
            return .available("Folder")
        }
        return .unavailable(missing("Kind description"))
    }

    nonisolated private static func missing(_ field: String) -> MetadataIssue {
        MetadataIssue(code: .missing, detail: "\(field) is unavailable.")
    }
}
