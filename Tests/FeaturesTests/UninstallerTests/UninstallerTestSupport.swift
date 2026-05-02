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
        bundleName: bundleName,
        executableName: executableName,
        version: "1.0",
        bundleSizeInBytes: 1024
    )
}

func makeAssociatedFile(
    url: URL,
    confidence: Confidence = .high,
    requiresAdmin: Bool = false
) -> AssociatedFile {
    AssociatedFile(
        url: url,
        sizeInBytes: 512,
        lastModified: Date(),
        confidence: confidence,
        reason: "Test",
        requiresAdmin: requiresAdmin
    )
}

func makeTempDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
