import Core
import Foundation

// MARK: - ConfidenceLevel

/// Coarse confidence bucket exposed to the UI for default-selection logic.
public enum ConfidenceLevel: Int, Sendable, Hashable, Comparable, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Display label used in the table column.
    public var label: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

// MARK: - ScoreResult

/// Result of scoring a candidate path against app metadata.
public struct ScoreResult: Sendable, Hashable {
    /// Numeric confidence in [0, 1].
    public let score: Double
    /// Human-readable reason(s) that contributed to this score.
    public let reasons: [String]

    public init(score: Double, reasons: [String]) {
        self.score = score
        self.reasons = reasons
    }

    public var confidenceLevel: ConfidenceLevel {
        if self.score >= MatchScorer.highCutoff { return .high }
        if self.score >= MatchScorer.mediumCutoff { return .medium }
        return .low
    }
}

// MARK: - MatchScorer

/// Scores a file-system path against the metadata of a candidate app.
///
/// Scoring rules (additive, capped at 1.0):
/// - Exact `bundleID` component in the last path component: +0.70
/// - Exact `bundleID` component anywhere in path:          +0.50
/// - Bundle name substring (case-insensitive) in path:     +0.25
/// - Executable name match in path:                        +0.15
///
/// False-positive guard: single-word tokens shorter than 4 characters do not
/// contribute to the name/executable score.
public struct MatchScorer: Sendable {
    // MARK: Cutoffs

    /// Score at or above this value → `.high` confidence.
    public static let highCutoff: Double = 0.65
    /// Score at or above this value → `.medium` confidence.
    public static let mediumCutoff: Double = 0.25

    public init() {}

    // MARK: Public API

    /// Score `candidateURL` against `metadata`.
    public func score(_ candidateURL: URL, against metadata: AppMetadata) -> ScoreResult {
        let pathLower = candidateURL.path.lowercased()
        let lastLower = candidateURL.lastPathComponent.lowercased()
        let bundleIDLower = metadata.bundleID.lowercased()
        let nameLower = metadata.displayName.lowercased()
        let execLower = metadata.executableName.lowercased()

        var total = 0.0
        var reasons: [String] = []

        // Exact bundle-ID in last component (highest signal)
        if lastLower.contains(bundleIDLower) {
            total += 0.70
            reasons.append("Bundle ID match in filename")
        } else if pathLower.contains(bundleIDLower) {
            // Bundle-ID anywhere in path (e.g. a container directory)
            total += 0.50
            reasons.append("Bundle ID match in path")
        }

        // Bundle-ID reversed-domain components (each component is signal)
        let idComponents = metadata.bundleID.split(separator: ".").map { $0.lowercased() }
        let longComponents = idComponents.filter { $0.count >= 4 }
        if !longComponents.isEmpty {
            let matched = longComponents.filter { lastLower.contains($0) }
            if !matched.isEmpty, total < 0.50 {
                let partial = min(0.50, Double(matched.count) / Double(longComponents.count) * 0.50)
                total += partial
                reasons.append("Bundle ID component match (\(matched.joined(separator: ", ")))")
            }
        }

        // Display-name substring
        let nameToken = nameLower.trimmingCharacters(in: .whitespaces)
        if nameToken.count >= 4, lastLower.contains(nameToken) || pathLower.contains(nameToken) {
            total += 0.25
            reasons.append("App name match")
        }

        // Executable-name match
        if execLower.count >= 4, lastLower.contains(execLower) || pathLower.contains(execLower) {
            total += 0.15
            reasons.append("Executable name match")
        }

        return ScoreResult(score: min(total, 1.0), reasons: reasons)
    }
}
