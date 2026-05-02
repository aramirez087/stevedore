import DesignSystem
import SwiftUI

/// Renders the authentication-mode picker and credential inputs for the active mode.
public struct AuthSelector: View {
    @Bindable private var viewModel: ConnectDialogViewModel

    public init(viewModel: ConnectDialogViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let modes = ConnectDialogViewModel.availableModes(for: self.viewModel.selectedScheme)
        if modes.count > 1 {
            Picker("Authentication", selection: self.$viewModel.authMode) {
                ForEach(modes, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }

        switch self.viewModel.authMode {
        case .password:
            self.passwordFields
        case .sshKey:
            self.sshKeyFields
        case .iam:
            self.iamNote
        case .anonymous:
            EmptyView()
        }
    }

    // MARK: - Credential input sub-views

    private var passwordFields: some View {
        Group {
            self.usernameField
            HStack {
                Group {
                    if self.viewModel.showPassword {
                        SDTextField("Password", text: self.$viewModel.password)
                    } else {
                        SecureField("Password", text: self.$viewModel.password)
                            .textFieldStyle(.plain)
                            .padding(Spacing.xs)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(nsColor: .separatorColor))
                            )
                    }
                }
                Toggle("Show", isOn: self.$viewModel.showPassword)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
        }
    }

    private var sshKeyFields: some View {
        Group {
            self.usernameField
            HStack {
                Text(self.viewModel.sshKeyURL?.lastPathComponent ?? "No key selected")
                    .foregroundStyle(self.viewModel.sshKeyURL == nil
                        ? Color(nsColor: .secondaryLabelColor)
                        : Color(nsColor: .labelColor))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Choose…") {
                    Task { await self.viewModel.pickSSHKey() }
                }
                .buttonStyle(.bordered)
            }
            if let err = viewModel.validationErrors.first(where: { $0.field == .sshKeyURL }) {
                self.inlineError(err.message)
            }
            SDTextField("Passphrase (optional)", text: self.$viewModel.sshKeyPassphrase)
        }
    }

    private var iamNote: some View {
        SDLabel("Using ambient IAM credentials. No key input required.", variant: .secondary)
    }

    private var usernameField: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SDTextField("Username", text: self.$viewModel.username)
                .accessibilityValue(self.usernameAccessibilityValue)
            if let err = viewModel.validationErrors.first(where: { $0.field == .username }) {
                self.inlineError(err.message)
            }
        }
    }

    private var usernameAccessibilityValue: String {
        if let err = viewModel.validationErrors.first(where: { $0.field == .username }) {
            return "Error: \(err.message)"
        }
        return self.viewModel.username
    }

    private func inlineError(_ message: String) -> some View {
        Text(message)
            .font(Font.system(size: 11))
            .foregroundStyle(Color(nsColor: .systemRed))
            .accessibilityValue("Error: \(message)")
    }
}
