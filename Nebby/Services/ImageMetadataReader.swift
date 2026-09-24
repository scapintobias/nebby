import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ImageMetadataReader: Sendable {
    nonisolated func dimensions(
        for url: URL,
        contentType: MetadataValue<UTType>
    ) -> MetadataValue<FileItem.PixelDimensions> {
        switch contentType {
        case let .available(type):
            guard type.conforms(to: .image) else { return .notApplicable }
        case .unavailable:
            return .unavailable(
                MetadataIssue(
                    code: .missing,
                    detail: "Image applicability is unknown because the file type is unavailable."
                )
            )
        case .notApplicable:
            return .notApplicable
        }

        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else {
            return .unavailable(
                MetadataIssue(code: .readFailed, detail: "Image metadata could not be opened.")
            )
        }

        guard
            CGImageSourceGetCount(source) > 0,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
            let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
            width.intValue > 0,
            height.intValue > 0
        else {
            return .unavailable(
                MetadataIssue(code: .unsupported, detail: "Pixel dimensions are not available for this image.")
            )
        }

        return .available(.init(width: width.intValue, height: height.intValue))
    }
}
