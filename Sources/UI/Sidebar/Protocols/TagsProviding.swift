import Foundation

/// Returns the Finder tag names visible on a given volume.
///
/// `Sendable` so it can be awaited across actor boundaries.
/// Production: `NSWorkspace.shared.fileLabels` on the main actor.
public protocol TagsProviding: Sendable {
    func fetchTags(forVolumeAt url: URL) async -> [String]
}
