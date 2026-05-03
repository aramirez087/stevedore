import Core
import DesignSystem
import FeaturesOperations
import SwiftUI

/// Minimal transfers queue view that auto-shows when the operation queue is non-empty.
///
/// The full UITransfers panel (Session 20) is still a stub module; this inline
/// implementation provides the visual structure needed for Session 26.
struct TransfersPanel: View {
    let operations: [FeaturesOperations.Operation]

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SDLabel("Transfers", variant: .secondary)
                .padding(.bottom, Spacing.xs)
            ScrollView {
                LazyVStack(spacing: Spacing.xs) {
                    ForEach(self.operations, id: \.id) { op in
                        TransferRow(operation: op)
                    }
                }
            }
        }
        .padding(Spacing.sm)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - TransferRow

private struct TransferRow: View {
    let operation: FeaturesOperations.Operation

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: self.iconName)
                .foregroundStyle(self.theme.colors.accent)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                SDLabel(self.operation.descriptor.kind.displayName, variant: .primary)
                if let dest = operation.descriptor.destination {
                    SDLabel(dest.lastComponent ?? dest.posixString, variant: .secondary)
                }
            }
            Spacer()
            SDLabel(self.operation.state.displayName, variant: .caption)
        }
        .padding(.vertical, Spacing.xs)
    }

    private var iconName: String {
        switch self.operation.descriptor.kind {
        case .copy: "doc.on.doc"
        case .move: "arrow.right.doc.on.clipboard"
        case .delete, .trash: "trash"
        case .rename: "pencil"
        case .mkdir: "folder.badge.plus"
        case .symlink: "link"
        case .archive: "archivebox"
        case .extract: "arrow.up.bin"
        }
    }
}

// MARK: - Display helpers

private extension OperationKind {
    var displayName: String {
        switch self {
        case .copy: "Copy"
        case .move: "Move"
        case .delete: "Delete"
        case .rename: "Rename"
        case .mkdir: "New Folder"
        case .symlink: "Symlink"
        case .archive: "Archive"
        case .extract: "Extract"
        case .trash: "Trash"
        }
    }
}

private extension OperationState {
    var displayName: String {
        switch self {
        case .pending: "Waiting"
        case .active: "In Progress"
        case .paused: "Paused"
        case .completed: "Done"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }
}
