import DesignSystem
import FeaturesUninstaller
import SwiftUI

public struct UninstallerSheet: View {
    @Bindable private var viewModel: UninstallerViewModel
    private let onDismiss: () -> Void

    public init(viewModel: UninstallerViewModel, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let metadata = self.viewModel.appMetadata {
                AppHeader(
                    metadata: metadata,
                    totalBytes: self.viewModel.totalSelectedBytes
                )
                Divider()
            }
            self.contentArea
            Divider()
            ConfirmationFooter(
                confirmationText: self.viewModel.confirmationText,
                isEnabled: self.viewModel.appMetadata != nil,
                isExecuting: self.viewModel.isExecuting,
                onConfirm: {
                    Task { await self.viewModel.confirmUninstall() }
                    self.onDismiss()
                },
                onCancel: {
                    self.viewModel.cancel()
                    self.onDismiss()
                }
            )
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    @ViewBuilder
    private var contentArea: some View {
        switch self.viewModel.scanState {
        case .idle:
            UninstallerLauncher(viewModel: self.viewModel)
        case .scanning:
            VStack {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Scanning for associated files…")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            AssociatedFilesTable(viewModel: self.viewModel)
        case .failed(let message):
            ContentUnavailableView(
                "Scan Failed",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
