import Core

public enum IconRegistry {
    public static func symbolName(for kind: FileKind) -> String {
        switch kind {
        case .directory: "folder"
        case .symbolicLink: "link"
        case .socket: "network"
        case .fifo: "arrow.left.arrow.right.circle"
        case .blockDevice: "internaldrive"
        case .characterDevice: "terminal"
        case .regularFile: "doc"
        case .unknown: "doc"
        }
    }

    /// Dictionary lookup keeps cyclomatic complexity at 1 (single branch on lookup miss).
    public static func symbolName(forExtension ext: String) -> String {
        self.extensionSymbols[ext.lowercased()] ?? "doc"
    }

    private static let extensionSymbols: [String: String] = [
        "pdf": "doc.richtext",
        "jpg": "photo",
        "jpeg": "photo",
        "png": "photo",
        "gif": "photo",
        "heic": "photo",
        "tiff": "photo",
        "bmp": "photo",
        "webp": "photo",
        "mp4": "film",
        "mov": "film",
        "avi": "film",
        "mkv": "film",
        "m4v": "film",
        "mp3": "music.note",
        "aac": "music.note",
        "flac": "music.note",
        "wav": "music.note",
        "m4a": "music.note",
        "ogg": "music.note",
        "zip": "archivebox",
        "tar": "archivebox",
        "gz": "archivebox",
        "bz2": "archivebox",
        "7z": "archivebox",
        "rar": "archivebox",
        "xz": "archivebox",
        "swift": "swift",
        "py": "terminal",
        "js": "chevron.left.forwardslash.chevron.right",
        "ts": "chevron.left.forwardslash.chevron.right",
        "html": "globe",
        "htm": "globe",
        "json": "doc.badge.gearshape",
        "yaml": "doc.badge.gearshape",
        "yml": "doc.badge.gearshape",
        "toml": "doc.badge.gearshape",
        "xml": "doc.badge.gearshape",
        "plist": "doc.badge.gearshape",
        "md": "doc.text",
        "markdown": "doc.text",
        "app": "app.badge",
        "dmg": "opticaldiscdrive",
        "pkg": "shippingbox",
        "txt": "doc.text",
        "sh": "terminal",
        "bash": "terminal",
        "zsh": "terminal",
        "fish": "terminal",
    ]
}
