import AppKit
import Core
import Foundation

public enum TextPreviewRenderer {
    static let readLimit = 1024 * 1024

    public static func render(item: FileItem) async -> PreviewPayload? {
        guard item.kind == .regularFile, item.path.scheme == .local else { return nil }
        let url = URL(fileURLWithPath: item.path.posixString)
        return await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
            let slice = data.prefix(Self.readLimit)
            let (text, _) = Self.detectAndDecode(slice)
            guard let text else { return nil }
            let nsText = text as NSString
            guard let rtfData = Self.attributedString(text).rtf(
                from: NSRange(location: 0, length: nsText.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            ) else { return nil }
            return PreviewPayload(mimeType: "text/rtf", data: rtfData)
        }.value
    }

    /// Returns (decoded string, detected encoding). Tries BOM first, then UTF-8, then Latin-1.
    static func detectAndDecode(_ data: Data) -> (String?, String.Encoding) {
        if data.starts(with: [0xFE, 0xFF]) {
            return (String(data: data, encoding: .utf16BigEndian), .utf16BigEndian)
        }
        if data.starts(with: [0xFF, 0xFE]) {
            return (String(data: data, encoding: .utf16LittleEndian), .utf16LittleEndian)
        }
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return (String(data: data.dropFirst(3), encoding: .utf8), .utf8)
        }
        if let s = String(data: data, encoding: .utf8) {
            return (s, .utf8)
        }
        return (String(data: data, encoding: .isoLatin1), .isoLatin1)
    }

    private static func attributedString(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.textColor,
            ]
        )
    }
}
