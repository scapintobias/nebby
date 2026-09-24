import Foundation
import UniformTypeIdentifiers

struct FileItem: Identifiable, Sendable {
    enum ItemKind: String, Equatable, Sendable {
        case file
        case folder
        case symbolicLink
        case other
    }

    struct PixelDimensions: Equatable, Sendable {
        let width: Int
        let height: Int
    }

    struct SystemIconReference: Equatable, Sendable {
        let fileURL: URL
    }

    let id: URL
    let url: URL
    let name: String
    let itemKind: MetadataValue<ItemKind>
    let contentType: MetadataValue<UTType>
    let kindDescription: MetadataValue<String>
    let byteSize: MetadataValue<Int64>
    let creationDate: MetadataValue<Date>
    let modificationDate: MetadataValue<Date>
    let imageDimensions: MetadataValue<PixelDimensions>
    let systemIcon: SystemIconReference
}
