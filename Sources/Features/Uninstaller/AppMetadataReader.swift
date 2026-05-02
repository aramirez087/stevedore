import Foundation

public struct AppMetadataReader: AppMetadataReading {
    public init() {}

    public func readMetadata(from bundleURL: URL) throws -> AppMetadata {
        let plistURL = bundleURL.appending(path: "Contents/Info.plist", directoryHint: .notDirectory)
        guard FileManager.default.fileExists(atPath: plistURL.path(percentEncoded: false)) else {
            throw UninstallerError.notAnAppBundle(bundleURL)
        }
        let data = try Data(contentsOf: plistURL)
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let bundleID = plist["CFBundleIdentifier"] as? String,
              let executableName = plist["CFBundleExecutable"] as? String
        else {
            throw UninstallerError.invalidInfoPlist(bundleURL)
        }
        let bundleName = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? bundleURL.deletingPathExtension().lastPathComponent
        let version = plist["CFBundleShortVersionString"] as? String
        let size = Self.computeSize(at: bundleURL)
        return AppMetadata(
            bundleURL: bundleURL,
            bundleID: bundleID,
            bundleName: bundleName,
            executableName: executableName,
            version: version,
            bundleSizeInBytes: size
        )
    }

    private static func computeSize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                  values.isDirectory != true,
                  let size = values.fileSize
            else { continue }
            total += Int64(size)
        }
        return total
    }
}
