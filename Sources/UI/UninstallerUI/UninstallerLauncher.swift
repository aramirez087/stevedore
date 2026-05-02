import DesignSystem
import FeaturesUninstaller
import SwiftUI

public struct UninstallerLauncher: View {
    @Bindable private var viewModel: UninstallerViewModel

    @Environment(\.theme) private var theme

    public init(viewModel: UninstallerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "trash")
                .font(.system(size: 48))
                .foregroundStyle(self.theme.colors.textSecondary)
            Text("Drop an app here to find associated files")
                .font(self.theme.typography.body)
                .foregroundStyle(self.theme.colors.textSecondary)
            if let error = self.viewModel.dropError {
                Text(error)
                    .font(self.theme.typography.caption)
                    .foregroundStyle(self.theme.colors.danger)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            Task { await self.viewModel.load(appURL: url) }
            return true
        }
    }
}
