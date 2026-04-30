/// One file's git porcelain v2 status, normalized into Stevedore vocabulary.
public struct GitFileStatus: Hashable, Sendable, Codable {
    /// Working-tree side of the index/worktree status pair.
    public enum WorktreeState: String, Codable, Sendable, Hashable, CaseIterable {
        case unmodified
        case modified
        case added
        case deleted
        case renamed
        case copied
        case untracked
        case ignored
        case typeChanged
        case conflicted
    }

    public let path: FilePath
    public let indexState: WorktreeState
    public let worktreeState: WorktreeState

    public init(path: FilePath, indexState: WorktreeState, worktreeState: WorktreeState) {
        self.path = path
        self.indexState = indexState
        self.worktreeState = worktreeState
    }
}
