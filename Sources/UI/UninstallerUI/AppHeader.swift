import AppKit
import Core
import FeaturesUninstaller
import SwiftUI

// MARK: - AppHeader

/// Displays the app icon, display name, version string, and aggregate size
/// (bundle + selected associated files).
public struct AppHeader: View {
    private let metadata: AppMetadata
    private let bundleSizeBytes: Int64
    private let selectedBytes: Int64

    public init(
        metadata: AppMetadata,
        bundleSizeBytes: Int64,
        selectedBytes: Int64
    ) {
        self.metadata = metadata
        self.bundleSizeBytes = bundleSizeBytes
        self.selectedBytes = selectedBytes
    }

    public var body: some View {
        HStack(spacing: 16) {
            self.appIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(self.metadata.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                if let version = metadata.versionLabel {
                    Text("Version \(version)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(self.totalSizeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    // MARK: Private

    private var appIcon: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: self.metadata.bundleURL.path))
            .resizable()
            .frame(width: 64, height: 64)
            .accessibilityLabel("\(self.metadata.displayName) icon")
    }

    private var totalSizeLabel: String {
        let total = self.bundleSizeBytes + self.selectedBytes
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            + " total (bundle + selected support files)"
    }
}
