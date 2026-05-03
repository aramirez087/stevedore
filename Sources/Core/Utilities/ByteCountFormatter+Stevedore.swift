import Foundation

/// A `Sendable` wrapper around `Foundation.ByteCountFormatter`.
///
/// The underlying `NSObject`-based formatter is constructed per call so it is
/// never shared across actors. Stored configuration is value-type and `Sendable`.
public struct ByteSizeFormatter: Sendable, Hashable {
    /// Whether to use powers of 1024 (binary) or 1000 (decimal).
    public enum Mode: String, Sendable, Hashable, CaseIterable {
        case binary // KiB / MiB / GiB …
        case decimal // KB / MB / GB …
    }

    public let mode: Mode
    public let locale: Locale
    public let allowsZeroRepresentation: Bool

    public init(
        mode: Mode = .binary,
        locale: Locale = .current,
        allowsZeroRepresentation: Bool = true
    ) {
        self.mode = mode
        self.locale = locale
        self.allowsZeroRepresentation = allowsZeroRepresentation
    }

    /// Formats an absolute byte count.
    /// Negative values are formatted as their absolute value with a leading "-".
    public func string(fromBytes bytes: Int64) -> String {
        let isNegative = bytes < 0
        let formatter = ByteCountFormatter()
        formatter.countStyle = self.mode == .binary ? .binary : .decimal
        formatter.allowsNonnumericFormatting = self.allowsZeroRepresentation
        let result = formatter.string(fromByteCount: isNegative ? -bytes : bytes)
        return isNegative ? "-" + result : result
    }

    /// Formats from `FileAttributes`. Returns `nil` when `sizeInBytes` is `nil`.
    public func string(from attributes: FileAttributes) -> String? {
        guard let size = attributes.sizeInBytes else { return nil }
        return self.string(fromBytes: size)
    }
}
