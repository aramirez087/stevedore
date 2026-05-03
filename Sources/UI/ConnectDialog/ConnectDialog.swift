import Core
import DesignSystem
import SwiftUI

/// Top-level connect-to-server modal.
///
/// Present as a sheet; the host provides `onSave`, `onConnect`, and `onCancel`
/// callbacks on the `viewModel` before presentation.
public struct ConnectDialog: View {
    @Bindable private var viewModel: ConnectDialogViewModel

    public init(viewModel: ConnectDialogViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            self.header
            self.schemePicker
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    self.displayNameField
                    self.formBody
                    Divider()
                    TestConnectionButton(viewModel: self.viewModel)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
            }
            Divider()
            self.buttonBar
        }
        .padding(Spacing.lg)
        .frame(minWidth: 460, idealWidth: 460, maxWidth: 560, minHeight: 480)
    }

    // MARK: - Sub-views

    private var header: some View {
        SDLabel(self.isEditMode ? "Edit Connection" : "New Connection", variant: .primary)
    }

    private var schemePicker: some View {
        Picker("Protocol", selection: self.$viewModel.selectedScheme) {
            ForEach(ConnectionScheme.allCases.filter { $0 != .local }, id: \.self) { scheme in
                Text(scheme.displayLabel).tag(scheme)
            }
        }
        .pickerStyle(.segmented)
    }

    private var displayNameField: some View {
        SDTextField("Display Name (optional)", text: self.$viewModel.displayName)
    }

    @ViewBuilder
    private var formBody: some View {
        switch self.viewModel.selectedScheme {
        case .sftp:
            SFTPForm(viewModel: self.viewModel)
        case .ftp:
            FTPForm(viewModel: self.viewModel)
        case .webdav:
            WebDAVForm(viewModel: self.viewModel)
        case .s3:
            S3Form(viewModel: self.viewModel)
        case .smb:
            SMBForm(viewModel: self.viewModel)
        case .local:
            EmptyView()
        }
    }

    private var buttonBar: some View {
        HStack {
            SDButton("Cancel", style: .secondary) { self.viewModel.cancel() }
            Spacer()
            SDButton("Save", style: .secondary) {
                Task { await self.viewModel.save() }
            }
            .disabled(self.viewModel.isSaving)
            SDButton("Connect", style: .primary) {
                Task { await self.viewModel.connect() }
            }
            .disabled(self.viewModel.isSaving)
        }
    }

    private var isEditMode: Bool {
        !self.viewModel.hostname.isEmpty
    }
}

// MARK: - ConnectionScheme display

private extension ConnectionScheme {
    var displayLabel: String {
        switch self {
        case .sftp: "SFTP"
        case .ftp: "FTP"
        case .webdav: "WebDAV"
        case .s3: "S3"
        case .smb: "SMB"
        case .local: "Local"
        }
    }
}
