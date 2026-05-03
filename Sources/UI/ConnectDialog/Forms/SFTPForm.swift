import DesignSystem
import SwiftUI

/// Form fields for SFTP connections.
public struct SFTPForm: View {
    @Bindable private var viewModel: ConnectDialogViewModel

    public init(viewModel: ConnectDialogViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            self.hostnameField
            self.portField(placeholder: "22")
            self.remotePathField
            AuthSelector(viewModel: self.viewModel)
        }
    }

    private var hostnameField: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SDTextField("Server Address", text: self.$viewModel.hostname)
                .accessibilityValue(self.hostnameAccessibilityValue)
            if let err = viewModel.validationErrors.first(where: { $0.field == .hostname }) {
                self.inlineError(err.message)
            }
        }
    }

    private var hostnameAccessibilityValue: String {
        if let err = viewModel.validationErrors.first(where: { $0.field == .hostname }) {
            return "Error: \(err.message)"
        }
        return self.viewModel.hostname
    }

    private func portField(placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SDTextField("Port (default \(placeholder))", text: self.$viewModel.portString)
                .accessibilityValue(self.portAccessibilityValue)
            if let err = viewModel.validationErrors.first(where: { $0.field == .port }) {
                self.inlineError(err.message)
            }
        }
    }

    private var portAccessibilityValue: String {
        if let err = viewModel.validationErrors.first(where: { $0.field == .port }) {
            return "Error: \(err.message)"
        }
        return self.viewModel.portString
    }

    private var remotePathField: some View {
        SDTextField("Remote Path (optional)", text: self.$viewModel.remotePath)
    }

    private func inlineError(_ message: String) -> some View {
        Text(message)
            .font(Font.system(size: 11))
            .foregroundStyle(Color(nsColor: .systemRed))
            .accessibilityValue("Error: \(message)")
    }
}
