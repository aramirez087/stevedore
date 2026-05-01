import AppKit
import Core
import Foundation

public enum ImagePreviewRenderer {
    public static func render(item: FileItem, maxDimension: CGFloat = 1024) async -> PreviewPayload? {
        guard item.kind == .regularFile, item.path.scheme == .local else { return nil }
        let url = URL(fileURLWithPath: item.path.posixString)
        return await Task.detached(priority: .utility) {
            guard let image = NSImage(contentsOf: url) else { return nil }
            let resampled = Self.resample(image, maxDimension: maxDimension)
            guard let tiff = resampled.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:])
            else { return nil }
            return PreviewPayload(mimeType: "image/png", data: png)
        }.value
    }

    static func resample(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        guard scale < 1.0 else { return image }
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        let result = NSImage(size: newSize)
        result.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        result.unlockFocus()
        return result
    }
}
