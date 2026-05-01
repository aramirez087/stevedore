import Core
import Foundation
import XCTest

func makePreviewItem(
    name: String,
    dir: String = "/tmp/preview-tests",
    kind: FileKind = .regularFile
) -> FileItem {
    FileItem(
        path: FilePath(scheme: .local, posix: "\(dir)/\(name)"),
        kind: kind
    )
}

@discardableResult
func makeTempFile(name: String, content: Data) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("PreviewTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent(name)
    try content.write(to: url)
    return url
}

@discardableResult
func makeTempFile(name: String, text: String, encoding: String.Encoding = .utf8) throws -> URL {
    guard let data = text.data(using: encoding) else {
        throw NSError(
            domain: "PreviewTests",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "encoding failed for \(encoding)"]
        )
    }
    return try makeTempFile(name: name, content: data)
}

/// Creates a small valid 1x1 PNG in memory.
func makeMinimalPNG() -> Data {
    // 1×1 white PNG (standard minimal PNG bytes)
    let bytes: [UInt8] = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR length + type
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, // 8-bit RGB, CRC
        0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT
        0x54, 0x08, 0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, // compressed pixel
        0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0xCC, 0x59, // continuation
        0xE7, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, // IEND
        0x44, 0xAE, 0x42, 0x60, 0x82, // IEND data
    ]
    return Data(bytes)
}
