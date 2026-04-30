/// Discrete categories a `FileItem` can fall into.
///
/// Kept intentionally coarse — refinements (e.g., bundle vs. plain directory)
/// belong in `FileAttributes` flags, not new cases here.
public enum FileKind: String, Codable, Sendable, Hashable, CaseIterable {
    case regularFile
    case directory
    case symbolicLink
    case socket
    case fifo
    case blockDevice
    case characterDevice
    case unknown
}
