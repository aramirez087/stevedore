import FeaturesUninstaller
import Foundation
import XCTest

func makeTestBundle(
    in directory: URL,
    bundleID: String = "com.example.TestApp",
    bundleName: String = "TestApp",
    executableName: String = "TestApp",
    version: String? = "1.0"
) throws -> URL {
    let bundleURL = directory.appending(path: "\(bundleName).app", directoryHint: .isDirectory)
    let contentsURL = bundleURL.appending(path: "Contents", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
    var plist: [String: Any] = [
        "CFBundleIdentifier": bundleID,
        "CFBundleExecutable": executableName,
        "CFBundleName": bundleName,
    ]
    if let version {
        plist["CFBundleShortVersionString"] = version
        plist["CFBundleVersion"] = version
    }
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    let plistURL = contentsURL.appending(path: "Info.plist", directoryHint: .notDirectory)
    try data.write(to: plistURL)
    return bundleURL
}

func makeAppMetadata(
    bundleURL: URL,
    bundleID: String = "com.example.TestApp",
    bundleName: String = "TestApp",
    executableName: String = "TestApp"
) -> AppMetadata {
    AppMetadata(
        bundleURL: bundleURL,
        bundleID: bundleID,
        displayName: bundleName,
        executableName: executableName,
        version: "1.0",
        shortVersion: nil
    )
}

func makeAssociatedFile(
    url: URL,
    confidence: ConfidenceLevel = .high,
    requiresAdmin: Bool = false
) -> AssociatedFile {
    let score: Double
    switch confidence {
    case .high: score = 0.80
    case .medium: score = 0.40
    case .low: score = 0.10
    }
    return AssociatedFile(
        url: url,
        sizeInBytes: 512,
        modificationDate: Date(),
        scoreResult: ScoreResult(score: score, reasons: ["Test"]),
        requiresAdmin: requiresAdmin
    )
}

func makeTempDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
