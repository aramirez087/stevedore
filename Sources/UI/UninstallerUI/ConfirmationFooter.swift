import Core
import FeaturesUninstaller
import SwiftUI

// MARK: - ConfirmationFooter

/// Displays the live summary of what will be moved to Trash, with a primary
/// "Move to Trash" button and a secondary "Cancel" button.
///
/// The confirmation text is recomputed from `viewModel` on every render, so
/// it is always up-to-date with the current selection.
public struct ConfirmationFooter: View {
    @Bindable var viewModel: UninstallerViewModel

    public init(viewModel: UninstallerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                self.confirmationLabel
                Spacer()
                Button("Cancel") { self.viewModel.cancel() }
                    .keyboardShortcut(.cancelAction)
                Button(role: .destructive) {
                    Task { await self.viewModel.confirm() }
                } label: {
                    Text(self.trashButtonLabel)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!self.viewModel.canConfirm)
            }
            .padding()
        }
    }

    // MARK: - Private

    private var confirmationLabel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(self.trashButtonLabel)
                .font(.headline)
            if self.viewModel.canConfirm {
                Text(self.sizeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var trashButtonLabel: String {
        let count = self.viewModel.confirmationItemCount
        return "Move \(count) \(count == 1 ? "item" : "items") to Trash"
    }

    private var sizeLabel: String {
        ByteCountFormatter.string(
            fromByteCount: self.viewModel.selectedAssociatedBytes,
            countStyle: .file
        ) + " in support files"
    }
}
