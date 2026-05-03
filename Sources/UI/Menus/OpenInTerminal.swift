import AppKit
import Core

/// Launches a terminal application at the given local directory path.
///
/// Only local paths are supported. Remote paths are silently ignored because
/// a remote shell session is not the same as a local terminal window.
public enum OpenInTerminal {
    /// Bundle identifiers of known terminal apps, tried in order when `preferred` is empty.
    public static let knownBundleIDs: [String] = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.mitchellh.ghostty",
    ]

    /// Launches the preferred terminal at `path`.
    ///
    /// - Parameters:
    ///   - path: Directory to open. Remote paths are ignored.
    ///   - preferred: Bundle identifier from Settings. Falls back to the first installed
    ///     app from `knownBundleIDs` when empty or not found.
    public static func launch(path: FilePath, using preferred: String) {
        guard path.scheme == .local else { return }
        let bundleID = self.resolvedBundleID(preferred: preferred)
        guard let bundleID,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: appURL, configuration: config)
    }

    // MARK: - Private

    private static func resolvedBundleID(preferred: String) -> String? {
        if !preferred.isEmpty,
           NSWorkspace.shared.urlForApplication(withBundleIdentifier: preferred) != nil {
            return preferred
        }
        return self.knownBundleIDs.first {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil
        }
    }
}
