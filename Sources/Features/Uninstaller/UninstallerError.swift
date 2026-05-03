import Foundation

public enum UninstallerError: LocalizedError, Sendable {
    case notAnAppBundle(URL)
    case invalidInfoPlist(URL)
    case trashFailed(URL, any Error)

    public var errorDescription: String? {
        switch self {
        case .notAnAppBundle(let url):
            "'\(url.lastPathComponent)' is not an app bundle (missing Contents/Info.plist)."
        case .invalidInfoPlist(let url):
            "'\(url.lastPathComponent)' has an invalid Info.plist (missing CFBundleIdentifier or CFBundleExecutable)."
        case .trashFailed(let url, let error):
            "Failed to move '\(url.lastPathComponent)' to Trash: \(error.localizedDescription)"
        }
    }
}
