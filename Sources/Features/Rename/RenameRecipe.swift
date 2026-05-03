public struct RenameRecipe: Sendable, Codable, Hashable {
    public let steps: [RenameStep]

    public init(steps: [RenameStep]) {
        self.steps = steps
    }

    public static let identity = Self(steps: [])
}
