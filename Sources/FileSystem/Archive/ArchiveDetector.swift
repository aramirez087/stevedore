import Core
import Foundation

/// Detects archive formats by file extension and magic bytes.
///
/// Only formats Stevedore handles natively are recognized. Pure `.gz` or
/// `.bz2` (without a wrapping tar) are not in scope and return `nil`.
public enum ArchiveDetector {
    /// Detect the archive format of a file at `url`.
    ///
    /// Extension-based detection is attempted first (cheaper). If the
    /// extension is ambiguous or absent, the first 264 bytes are inspected
    /// for magic signatures.
    public static func detect(at url: URL) async -> ArchiveFormat? {
        let name = url.lastPathComponent
        if let format = self.detectByExtension(name) {
            return format
        }
        let data = await Task.detached(priority: .userInitiated) {
            guard let fh = FileHandle(forReadingAtPath: url.path) else { return Data() }
            defer { try? fh.close() }
            return fh.readData(ofLength: 264)
        }.value
        return self.detectByMagic(data)
    }

    /// Returns `true` when `path` refers to a supported archive.
    public static func isArchive(_ url: URL) async -> Bool {
        await self.detect(at: url) != nil
    }

    /// Detect by filename extension. Multi-suffix forms are matched first.
    public static func detectByExtension(_ name: String) -> ArchiveFormat? {
        let lower = name.lowercased()
        if lower.hasSuffix(".tar.gz") || lower.hasSuffix(".tgz") { return .tarGzip }
        if lower.hasSuffix(".tar.bz2") || lower.hasSuffix(".tbz2") { return .tarBzip2 }
        if lower.hasSuffix(".tar") { return .tar }
        if lower.hasSuffix(".zip") { return .zip }
        return nil
    }

    /// Detect by magic bytes (first 264 bytes of the file).
    public static func detectByMagic(_ data: Data) -> ArchiveFormat? {
        guard data.count >= 2 else { return nil }
        // ZIP: PK\x03\x04
        if data.count >= 4,
           data[0] == 0x50, data[1] == 0x4B, data[2] == 0x03, data[3] == 0x04 {
            return .zip
        }
        // GZip: \x1F\x8B
        if data[0] == 0x1F, data[1] == 0x8B { return .tarGzip }
        // BZip2: BZh
        if data.count >= 3, data[0] == 0x42, data[1] == 0x5A, data[2] == 0x68 { return .tarBzip2 }
        // ustar magic at offset 257
        if data.count >= 262 {
            let magic = data[257 ..< 262]
            if magic.elementsEqual([0x75, 0x73, 0x74, 0x61, 0x72]) { return .tar }
        }
        return nil
    }
}
