/// Stevedore-native progress value.
///
/// Distinct from `Foundation.Progress` so it can be `Sendable` and `Codable`
/// without inheriting `NSObject` semantics. Total bytes are optional because
/// some sources (e.g., streaming archives) cannot report them up front.
public struct Progress: Hashable, Sendable, Codable {
    /// Phase of a multi-stage operation.
    public enum Phase: String, Codable, Sendable, Hashable, CaseIterable {
        case queued
        case preparing
        case transferring
        case verifying
        case finalizing
        case completed
        case cancelling
    }

    public let bytesDone: Int64
    public let bytesTotal: Int64?
    public let phase: Phase
    public let throughputBytesPerSecond: Int64?
    public let currentItemDisplayName: String?

    public init(
        bytesDone: Int64,
        bytesTotal: Int64?,
        phase: Phase,
        throughputBytesPerSecond: Int64? = nil,
        currentItemDisplayName: String? = nil
    ) {
        self.bytesDone = bytesDone
        self.bytesTotal = bytesTotal
        self.phase = phase
        self.throughputBytesPerSecond = throughputBytesPerSecond
        self.currentItemDisplayName = currentItemDisplayName
    }

    /// Fractional completion in `[0, 1]`, or `nil` when total is unknown.
    public var fraction: Double? {
        guard let total = bytesTotal, total > 0 else { return nil }
        return Double(self.bytesDone) / Double(total)
    }
}
