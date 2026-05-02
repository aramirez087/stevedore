public enum Confidence: Int, Comparable, Sendable, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func from(score: Double) -> Self {
        if score >= 0.7 { return .high }
        if score >= 0.4 { return .medium }
        return .low
    }
}
