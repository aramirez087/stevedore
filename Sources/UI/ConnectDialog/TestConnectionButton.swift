import DesignSystem
import SwiftUI

/// A button that triggers `viewModel.testConnection()` and surfaces
/// the result inline. Credential material is never shown in the status message.
public struct TestConnectionButton: View {
    @Bindable private var viewModel: ConnectDialogViewModel

    public init(viewModel: ConnectDialogViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                SDButton("Test Connection", style: .secondary) {
                    Task { await self.viewModel.testConnection() }
                }
                .disabled(self.viewModel.testStatus == .testing)

                if self.viewModel.testStatus == .testing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                }
            }

            self.statusMessage
        }
    }

    @ViewBuilder
    private var statusMessage: some View {
        let message = self.viewModel.testStatus.userMessage
        if !message.isEmpty {
            HStack(spacing: Spacing.xs) {
                self.statusIcon
                Text(message)
                    .font(Font.system(size: 11))
                    .foregroundStyle(self.statusColor)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(message)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch self.viewModel.testStatus {
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(nsColor: .systemGreen))
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(Color(nsColor: .systemRed))
        default:
            EmptyView()
        }
    }

    private var statusColor: Color {
        switch self.viewModel.testStatus {
        case .success:
            Color(nsColor: .systemGreen)
        case .failure:
            Color(nsColor: .systemRed)
        default:
            Color(nsColor: .secondaryLabelColor)
        }
    }
}
