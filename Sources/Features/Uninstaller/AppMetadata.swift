import Foundation

public struct AppMetadata: Sendable {
    public let bundleURL: URL
    public let bundleID: String
    public let bundleName: String
    public let executableName: String
    public let version: String?
    public let bundleSizeInBytes: Int64

    public init(
        bundleURL: URL,
        bundleID: String,
        bundleName: String,
        executableName: String,
        version: String?,
        bundleSizeInBytes: Int64
    ) {
        self.bundleURL = bundleURL
        self.bundleID = bundleID
        self.bundleName = bundleName
        self.executableName = executableName
        self.version = version
        self.bundleSizeInBytes = bundleSizeInBytes
    }
}
