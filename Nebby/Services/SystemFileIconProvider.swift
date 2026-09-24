import AppKit
import SwiftUI

@MainActor
struct SystemFileIconProvider {
    func image(for reference: FileItem.SystemIconReference) -> Image {
        Image(nsImage: NSWorkspace.shared.icon(forFile: reference.fileURL.path))
    }
}
