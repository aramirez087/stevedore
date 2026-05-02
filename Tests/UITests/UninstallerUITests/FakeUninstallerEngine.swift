import Core
import FeaturesUninstaller
import Foundation

// MARK: - Fake builder helpers

/// Creates an `AssociatedFile` for use in tests without touching the real file system.
func makeAssociatedFile(
    path: String = "/Users/test/Library/Application Support/com.example.App",
    sizeInBytes: Int64 = 1024,
    modificationDate: Date? = nil,
    score: Double = 0.75,
    reasons: [String] = ["Bundle ID match in path"],
    requiresAdmin: Bool = false
) -> AssociatedFile {
    AssociatedFile(
        id: UUID(),
        url: URL(filePath: path),
        sizeInBytes: sizeInBytes,
        modificationDate: modificationDate ?? Date(timeIntervalSince1970: 1_700_000_000),
        scoreResult: ScoreResult(score: score, reasons: reasons),
        requiresAdmin: requiresAdmin
    )
}

/// Creates a high-confidence user-owned associated file.
func makeHighConfidenceFile(path: String = "/Users/test/Library/Caches/com.example.App") -> AssociatedFile {
    makeAssociatedFile(path: path, score: 0.80, reasons: ["Bundle ID match in path"])
}

/// Creates a medium-confidence user-owned associated file.
func makeMediumConfidenceFile(path: String = "/Users/test/Library/Logs/Example") -> AssociatedFile {
    makeAssociatedFile(path: path, score: 0.35, reasons: ["App name match"])
}

/// Creates a low-confidence user-owned associated file.
func makeLowConfidenceFile(path: String = "/Users/test/Library/Application Support/Logs") -> AssociatedFile {
    makeAssociatedFile(path: path, score: 0.10, reasons: ["Executable name match"])
}

/// Creates a system-owned associated file (requiresAdmin == true).
func makeSystemFile(path: String = "/Library/Application Support/com.example.App") -> AssociatedFile {
    makeAssociatedFile(path: path, score: 0.80, reasons: ["Bundle ID match in path"], requiresAdmin: true)
}

// MARK: - FakeAppMetadata

extension AppMetadata {
    static func fake(
        bundlePath: String = "/Applications/Example.app",
        bundleID: String = "com.example.App",
        displayName: String = "Example",
        executableName: String = "Example"
    ) -> AppMetadata {
        AppMetadata(
            bundleURL: URL(filePath: bundlePath),
            bundleID: bundleID,
            displayName: displayName,
            executableName: executableName,
            version: "100",
            shortVersion: "1.0.0"
        )
    }
}
