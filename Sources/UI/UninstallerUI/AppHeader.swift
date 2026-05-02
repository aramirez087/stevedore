import AppKit
import DesignSystem
import FeaturesUninstaller
import SwiftUI

public struct AppHeader: View {
    private let metadata: AppMetadata
    private let totalBytes: Int64

    @Environment(\.theme) private var theme

    public init(metadata: AppMetadata, totalBytes: Int64) {
        self.metadata = metadata
        self.totalBytes = totalBytes
    }

    public var body: some View {
        HStack(spacing: Spacing.md) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: self.metadata.bundleURL.path(percentEncoded: false)))
                .resizable()
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(self.metadata.bundleName)
                    .font(self.theme.typography.title)
                    .foregroundStyle(self.theme.colors.textPrimary)
                if let version = self.metadata.version {
                    Text("Version \(version)")
                        .font(self.theme.typography.caption)
                        .foregroundStyle(self.theme.colors.textSecondary)
                }
                Text(ByteCountFormatter.string(fromByteCount: self.totalBytes, countStyle: .file))
                    .font(self.theme.typography.caption)
                    .foregroundStyle(self.theme.colors.textSecondary)
            }
            Spacer()
        }
        .padding(Spacing.md)
    }
}
