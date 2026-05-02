import AppKit
import Core
import FeaturesUninstaller
import SwiftUI

// MARK: - UninstallerSheet

/// Modal sheet that shows the app header, associated-files table, and
/// confirmation footer for the "Move App to Trash" flow.
///
/// Present this sheet and supply a configured `UninstallerViewModel`.
/// The sheet dismisses itself by calling `viewModel.onDismiss`.
public struct UninstallerSheet: View {
    @Bindable var viewModel: UninstallerViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: UninstallerViewModel) {
        self.viewModel = viewModel
        viewModel.onDismiss = {}
    }

    public var body: some View {
        VStack(spacing: 0) {
            self.header
            Divider()
            self.content
            ConfirmationFooter(viewModel: self.viewModel)
        }
        .frame(minWidth: 680, minHeight: 480)
        .onAppear {
            self.viewModel.onDismiss = { self.dismiss() }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        if let meta = viewModel.metadata {
            AppHeader(
                metadata: meta,
                bundleSizeBytes: self.bundleSizeBytes(for: meta),
                selectedBytes: self.viewModel.selectedAssociatedBytes
            )
        } else {
            HStack {
                ProgressView()
                Text("Loading app info…")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch self.viewModel.scanState {
        case .idle:
            self.emptyState

        case .scanning:
            VStack {
                ProgressView("Scanning for associated files…")
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .ready:
            if self.viewModel.rows.isEmpty {
                self.noAssociatedFiles
            } else {
                self.filesTable
            }

        case .error(let message):
            self.errorState(message)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Drop a .app bundle to begin")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noAssociatedFiles: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("No associated files found.")
                .font(.headline)
            Text("Only the app bundle will be moved to Trash.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filesTable: some View {
        AssociatedFilesTable(rows: self.$viewModel.rows)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Could not load app")
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func bundleSizeBytes(for meta: AppMetadata) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: meta.bundleURL.path)
        return attrs?[.size] as? Int64 ?? 0
    }
}
