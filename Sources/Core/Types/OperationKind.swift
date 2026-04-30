/// Canonical archive container formats Stevedore handles natively.
public enum ArchiveFormat: String, Codable, Sendable, Hashable, CaseIterable {
    case zip
    case tar
    case tarGzip
    case tarBzip2
}

/// Discriminated set of file operations the operation engine can execute.
///
/// Hand-rolls `Codable` because `Swift.Codable` synthesis on enums with
/// associated values is supported but verbose; the explicit discriminator
/// also makes the persisted form easier to evolve.
public enum OperationKind: Hashable, Sendable, Codable {
    case copy
    case move
    case delete
    case rename
    case mkdir
    case symlink
    case archive(format: ArchiveFormat)
    case extract
    case trash

    private enum CodingKeys: String, CodingKey {
        case kind
        case format
    }

    private enum DiscriminatorValue: String, Codable {
        case copy
        case move
        case delete
        case rename
        case mkdir
        case symlink
        case archive
        case extract
        case trash
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let discriminator = try container.decode(DiscriminatorValue.self, forKey: .kind)
        switch discriminator {
        case .copy: self = .copy
        case .move: self = .move
        case .delete: self = .delete
        case .rename: self = .rename
        case .mkdir: self = .mkdir
        case .symlink: self = .symlink
        case .archive:
            let format = try container.decode(ArchiveFormat.self, forKey: .format)
            self = .archive(format: format)
        case .extract: self = .extract
        case .trash: self = .trash
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .copy: try container.encode(DiscriminatorValue.copy, forKey: .kind)
        case .move: try container.encode(DiscriminatorValue.move, forKey: .kind)
        case .delete: try container.encode(DiscriminatorValue.delete, forKey: .kind)
        case .rename: try container.encode(DiscriminatorValue.rename, forKey: .kind)
        case .mkdir: try container.encode(DiscriminatorValue.mkdir, forKey: .kind)
        case .symlink: try container.encode(DiscriminatorValue.symlink, forKey: .kind)
        case .archive(let format):
            try container.encode(DiscriminatorValue.archive, forKey: .kind)
            try container.encode(format, forKey: .format)
        case .extract: try container.encode(DiscriminatorValue.extract, forKey: .kind)
        case .trash: try container.encode(DiscriminatorValue.trash, forKey: .kind)
        }
    }
}

/// Conflict-resolution policy attached to an `OperationDescriptor`. Concrete
/// dialogs in downstream sessions will prompt the user; protocols and the
/// engine accept the policy as input so headless tests can drive operations
/// deterministically.
public enum ConflictPolicy: String, Codable, Sendable, Hashable, CaseIterable {
    case ask
    case overwrite
    case skip
    case rename
}
