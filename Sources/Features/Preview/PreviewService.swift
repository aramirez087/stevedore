import AppKit
import Core
import Foundation

public actor PreviewService: PreviewSource {
    private let cache: PreviewCache
    private let thumbnailGenerator: ThumbnailGenerator

    public init(
        cache: PreviewCache = PreviewCache(),
        thumbnailGenerator: ThumbnailGenerator = ThumbnailGenerator()
    ) {
        self.cache = cache
        self.thumbnailGenerator = thumbnailGenerator
    }

    // MARK: - PreviewSource

    public func thumbnail(for item: FileItem, size: CGSize) async throws -> Data? {
        guard item.path.scheme == .local else { return nil }
        let key = "thumb:\(item.path.posixString):\(Int(size.width))x\(Int(size.height))"
        if let cached = await self.cache.fetch(key: key) {
            return cached.data
        }
        let url = URL(fileURLWithPath: item.path.posixString)
        let data = try await self.thumbnailGenerator.thumbnail(for: url, size: size)
        if let data {
            await self.cache.store(PreviewPayload(mimeType: "image/png", data: data), forKey: key)
        }
        return data
    }

    public func preview(for item: FileItem) async throws -> PreviewPayload? {
        guard item.kind == .regularFile, item.path.scheme == .local else { return nil }
        let key = "preview:\(item.path.posixString)"
        if let cached = await self.cache.fetch(key: key) {
            return cached
        }
        let payload = try await self.dispatch(item: item)
        if let payload {
            await self.cache.store(payload, forKey: key)
        }
        return payload
    }

    // MARK: - Renderer dispatch

    private func dispatch(item: FileItem) async throws -> PreviewPayload? {
        let fileName = item.path.lastComponent ?? ""
        let ext = (fileName as NSString).pathExtension.lowercased()

        if Self.imageExtensions.contains(ext) {
            return await ImagePreviewRenderer.render(item: item)
        }
        if Self.codeExtensions.contains(ext) {
            return await CodePreviewRenderer.render(item: item)
        }
        if Self.textExtensions.contains(ext) {
            return await TextPreviewRenderer.render(item: item)
        }
        if await Self.isLikelyText(item: item) {
            return await TextPreviewRenderer.render(item: item)
        }
        let url = URL(fileURLWithPath: item.path.posixString)
        let data = try? await self.thumbnailGenerator.thumbnail(for: url, size: CGSize(width: 512, height: 512))
        return data.flatMap(\.self).map { PreviewPayload(mimeType: "image/png", data: $0) }
    }

    private static let imageExtensions: Set<String> = [
        "bmp", "gif", "heic", "heif", "ico", "jpeg", "jpg", "png", "svg", "tif", "tiff", "webp",
    ]

    private static let codeExtensions: Set<String> = [
        "bash", "c", "cc", "command", "cpp", "css", "cxx", "dockerfile", "fish",
        "go", "h", "hpp", "html", "htm", "java", "js", "json", "less",
        "m", "makefile", "mjs", "mm", "plist", "py", "pyw", "rb", "rs",
        "scss", "sh", "sql", "swift", "toml", "ts", "tsx", "xml",
        "yaml", "yml", "zsh",
    ]

    private static let textExtensions: Set<String> = [
        "conf", "csv", "env", "ini", "log", "md", "markdown", "rtf", "txt",
    ]

    /// Files with no null bytes in first 4 KB are treated as text.
    private static func isLikelyText(item: FileItem) async -> Bool {
        let url = URL(fileURLWithPath: item.path.posixString)
        return await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return false }
            return !data.prefix(4096).contains(0x00)
        }.value
    }
}
