import Core

public enum RenameStatus: Sendable, Hashable {
    case ok
    case collision
    case invalid(reason: String)
}

public struct RenameOutcome: Sendable, Hashable {
    public let item: FileItem
    public let targetName: String
    public let status: RenameStatus

    public init(item: FileItem, targetName: String, status: RenameStatus) {
        self.item = item
        self.targetName = targetName
        self.status = status
    }
}
