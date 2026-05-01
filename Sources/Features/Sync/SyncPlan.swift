import Core
import Foundation

// MARK: - SyncStep

/// A single executable step derived from a `Difference` and `SyncOptions`.
public enum SyncStep: Sendable {
    case copyToRight(relativePath: FilePath, left: FileItem)
    case copyToLeft(relativePath: FilePath, right: FileItem)
    case deleteFromRight(relativePath: FilePath)
    case deleteFromLeft(relativePath: FilePath)
    /// Right is overwritten with left content.
    case replaceRight(relativePath: FilePath, left: FileItem)
    /// Left is overwritten with right content.
    case replaceLeft(relativePath: FilePath, right: FileItem)
    /// Both sides were modified; requires manual resolution.
    case conflict(relativePath: FilePath, left: FileItem, right: FileItem)
}

// MARK: - SyncPlan

/// A derived, pure sync plan. No I/O. Deterministic for a given input.
public struct SyncPlan: Sendable {
    public let differences: [Difference]
    public let steps: [SyncStep]

    public init(differences: [Difference], steps: [SyncStep]) {
        self.differences = differences
        self.steps = steps
    }

    /// Build a plan from comparator output and sync options.
    ///
    /// Pure: no I/O, no async. Produces zero steps when all differences are `.matched`.
    public static func build(from differences: [Difference], options: SyncOptions) -> Self {
        var steps: [SyncStep] = []
        for diff in differences {
            if let step = Self.step(for: diff, options: options) {
                steps.append(step)
            }
        }
        return Self(differences: differences, steps: steps)
    }

    // MARK: Private

    private static func step(for diff: Difference, options: SyncOptions) -> SyncStep? {
        switch (diff.status, options.mode) {
        case (.matched, _):
            return nil

        case (.leftOnly, _):
            guard let left = diff.leftItem else { return nil }
            return .copyToRight(relativePath: diff.relativePath, left: left)

        case (.rightOnly, .oneWayMirror):
            return .deleteFromRight(relativePath: diff.relativePath)

        case (.rightOnly, .oneWayContribute):
            return nil

        case (.rightOnly, .twoWay):
            guard let right = diff.rightItem else { return nil }
            return .copyToLeft(relativePath: diff.relativePath, right: right)

        case (.modified, .oneWayMirror), (.modified, .oneWayContribute):
            guard let left = diff.leftItem else { return nil }
            return .copyToRight(relativePath: diff.relativePath, left: left)

        case (.modified, .twoWay):
            return self.twoWayModifiedStep(diff: diff, options: options)
        }
    }

    private static func twoWayModifiedStep(diff: Difference, options: SyncOptions) -> SyncStep? {
        guard let left = diff.leftItem, let right = diff.rightItem else { return nil }

        switch options.conflictResolution {
        case .manual:
            return .conflict(relativePath: diff.relativePath, left: left, right: right)

        case .newerWins:
            guard let leftMtime = left.attributes.modificationDate,
                  let rightMtime = right.attributes.modificationDate
            else {
                return .conflict(relativePath: diff.relativePath, left: left, right: right)
            }
            return leftMtime >= rightMtime
                ? .replaceRight(relativePath: diff.relativePath, left: left)
                : .replaceLeft(relativePath: diff.relativePath, right: right)

        case .largerWins:
            guard let leftSize = left.attributes.sizeInBytes,
                  let rightSize = right.attributes.sizeInBytes
            else {
                return .conflict(relativePath: diff.relativePath, left: left, right: right)
            }
            return leftSize >= rightSize
                ? .replaceRight(relativePath: diff.relativePath, left: left)
                : .replaceLeft(relativePath: diff.relativePath, right: right)
        }
    }
}
