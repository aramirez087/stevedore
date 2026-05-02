import Core
import Foundation

// MARK: - UninstallPlan

/// Pure value type that captures a complete uninstallation intent.
///
/// The `.app` bundle itself is always included.  `selectedFiles` is the
/// subset of `AssociatedFile` entries the user chose to remove.
public struct UninstallPlan: Sendable {
    public let metadata: AppMetadata
    public let selectedFiles: [AssociatedFile]

    public init(metadata: AppMetadata, selectedFiles: [AssociatedFile]) {
        self.metadata = metadata
        self.selectedFiles = selectedFiles
    }

    /// All URLs that will be moved to Trash: the `.app` bundle + selected files.
    public var urlsToTrash: [URL] {
        [self.metadata.bundleURL] + self.selectedFiles.map(\.url)
    }

    /// Aggregate byte count across selected associated files only (not the bundle itself).
    public var selectedFilesSize: Int64 {
        self.selectedFiles.reduce(0) { $0 + $1.sizeInBytes }
    }

    /// Total item count (app + selected files).
    public var totalItemCount: Int {
        1 + self.selectedFiles.count
    }
}
