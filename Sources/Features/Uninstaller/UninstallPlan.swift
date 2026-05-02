import Foundation

public struct UninstallPlan: Sendable {
    public let appMetadata: AppMetadata
    public let selectedFiles: [AssociatedFile]

    public init(appMetadata: AppMetadata, selectedFiles: [AssociatedFile]) {
        self.appMetadata = appMetadata
        self.selectedFiles = selectedFiles
    }

    public var totalBytes: Int64 {
        self.appMetadata.bundleSizeInBytes + self.selectedFiles.reduce(0) { $0 + $1.sizeInBytes }
    }
}
