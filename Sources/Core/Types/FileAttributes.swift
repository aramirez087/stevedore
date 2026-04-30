import Foundation

/// POSIX permission triple as a Sendable wire-friendly value.
public struct PosixPermissions: Hashable, Sendable, Codable {
    public let owner: UInt8
    public let group: UInt8
    public let other: UInt8

    public init(owner: UInt8, group: UInt8, other: UInt8) {
        self.owner = owner
        self.group = group
        self.other = other
    }

    /// Construct from a raw POSIX mode (low 9 bits used).
    public init(rawMode: UInt16) {
        self.owner = UInt8((rawMode >> 6) & 0o7)
        self.group = UInt8((rawMode >> 3) & 0o7)
        self.other = UInt8(rawMode & 0o7)
    }

    /// Pack back to a 9-bit POSIX mode.
    public var rawMode: UInt16 {
        (UInt16(self.owner) << 6) | (UInt16(self.group) << 3) | UInt16(self.other)
    }
}

/// Captures the metadata associated with a `FileItem`.
///
/// Sizes use `Int64` for cross-platform consistency. Timestamps are wall-clock
/// `Date`s; the originating provider is responsible for converting from its
/// native format (e.g., epoch seconds, `FILETIME`).
public struct FileAttributes: Hashable, Sendable, Codable {
    public let sizeInBytes: Int64?
    public let modificationDate: Date?
    public let creationDate: Date?
    public let permissions: PosixPermissions?
    public let isHidden: Bool
    public let isPackage: Bool
    public let isSymbolicLink: Bool
    public let symbolicLinkTarget: String?

    public init(
        sizeInBytes: Int64? = nil,
        modificationDate: Date? = nil,
        creationDate: Date? = nil,
        permissions: PosixPermissions? = nil,
        isHidden: Bool = false,
        isPackage: Bool = false,
        isSymbolicLink: Bool = false,
        symbolicLinkTarget: String? = nil
    ) {
        self.sizeInBytes = sizeInBytes
        self.modificationDate = modificationDate
        self.creationDate = creationDate
        self.permissions = permissions
        self.isHidden = isHidden
        self.isPackage = isPackage
        self.isSymbolicLink = isSymbolicLink
        self.symbolicLinkTarget = symbolicLinkTarget
    }

    /// Empty attributes — useful when constructing fakes or stubs where a
    /// provider has not yet populated metadata.
    public static let empty = Self()
}
