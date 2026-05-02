import Core
import Foundation

// MARK: - AppMetadata

/// Parsed metadata extracted from a `.app` bundle's `Info.plist`.
public struct AppMetadata: Sendable, Hashable {
    public let bundleURL: URL
    public let bundleID: String
    public let displayName: String
    public let executableName: String
    public let version: String?
    public let shortVersion: String?

    public init(
        bundleURL: URL,
        bundleID: String,
        displayName: String,
        executableName: String,
        version: String?,
        shortVersion: String?
    ) {
        self.bundleURL = bundleURL
        self.bundleID = bundleID
        self.displayName = displayName
        self.executableName = executableName
        self.version = version
        self.shortVersion = shortVersion
    }

    /// Human-readable version string, preferring `CFBundleShortVersionString`.
    public var versionLabel: String? {
        self.shortVersion ?? self.version
    }
}

// MARK: - AppMetadataReaderError

/// Errors thrown by `AppMetadataReader`.
public enum AppMetadataReaderError: Error, LocalizedError, Sendable {
    case notAnAppBundle(URL)
    case missingInfoPlist(URL)
    case missingRequiredKey(String)
    case malformedPlist(URL)

    public var errorDescription: String? {
        switch self {
        case .notAnAppBundle(let url):
            "'\(url.lastPathComponent)' is not a valid .app bundle."
        case .missingInfoPlist(let url):
            "'\(url.lastPathComponent)' is missing Contents/Info.plist."
        case .missingRequiredKey(let key):
            "Info.plist is missing required key '\(key)'."
        case .malformedPlist(let url):
            "Could not parse Info.plist in '\(url.lastPathComponent)'."
        }
    }
}

// MARK: - AppMetadataReader

/// Reads bundle metadata from a macOS `.app` bundle directory.
///
/// Validates that the path ends in `.app`, contains `Contents/Info.plist`,
/// and provides the required `CFBundleIdentifier` and `CFBundleExecutable` keys.
public struct AppMetadataReader: Sendable {
    public init() {}

    /// Parse the `Info.plist` of `bundleURL` and return an `AppMetadata`.
    /// - Throws: `AppMetadataReaderError` for any structural or key-absence problem.
    public func read(from bundleURL: URL) throws -> AppMetadata {
        guard bundleURL.pathExtension.lowercased() == "app" else {
            throw AppMetadataReaderError.notAnAppBundle(bundleURL)
        }

        let plistURL = bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Info.plist")

        guard FileManager.default.fileExists(atPath: plistURL.path) else {
            throw AppMetadataReaderError.missingInfoPlist(bundleURL)
        }

        guard let plist = NSDictionary(contentsOf: plistURL) else {
            throw AppMetadataReaderError.malformedPlist(bundleURL)
        }

        guard let bundleID = plist["CFBundleIdentifier"] as? String, !bundleID.isEmpty else {
            throw AppMetadataReaderError.missingRequiredKey("CFBundleIdentifier")
        }

        guard let executable = plist["CFBundleExecutable"] as? String, !executable.isEmpty else {
            throw AppMetadataReaderError.missingRequiredKey("CFBundleExecutable")
        }

        // Prefer CFBundleDisplayName → CFBundleName → executable name
        let displayName = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? executable

        let version = plist["CFBundleVersion"] as? String
        let shortVersion = plist["CFBundleShortVersionString"] as? String

        return AppMetadata(
            bundleURL: bundleURL,
            bundleID: bundleID,
            displayName: displayName,
            executableName: executable,
            version: version,
            shortVersion: shortVersion
        )
    }
}
