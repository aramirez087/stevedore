import Core
import FeaturesUninstaller
import SwiftUI
import UniformTypeIdentifiers

// MARK: - UninstallerLauncher

/// Drop-target landing view for the uninstaller.
///
/// The user can drag-and-drop a `.app` bundle onto this view to trigger the
/// uninstall sheet, or open the sheet via the app menu which calls `load(url:)`
/// programmatically.
///
/// Drop validation rules:
/// - Accepted UTT: `public.application` or a directory with `.app` path extension.
/// - Rejected: anything that does not end in `.app` or fails `AppMetadataReader`.
public struct UninstallerLauncher: View {
    @State private var viewModel = UninstallerViewModel()
    @State private var isSheetPresented = false
    @State private var isDraggingOver = false

    private static let acceptedTypes: [UTType] = [.application, .applicationBundle]

    public init() {}

    public var body: some View {
        ZStack {
            self.dropZone
        }
        .sheet(isPresented: self.$isSheetPresented) {
            UninstallerSheet(viewModel: self.viewModel)
        }
    }

    // MARK: - Drop zone

    private var dropZone: some View {
        VStack(spacing: 16) {
            Image(systemName: self.isDraggingOver ? "arrow.down.circle.fill" : "trash.circle")
                .font(.system(size: 56))
                .foregroundStyle(self.isDraggingOver ? .blue : .secondary)
                .animation(.easeInOut(duration: 0.15), value: self.isDraggingOver)

            Text("Drop an app here to uninstall it")
                .font(.title3)
                .foregroundStyle(.secondary)

            if let error = viewModel.dropError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(self.isDraggingOver ? Color.blue.opacity(0.08) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(self.isDraggingOver ? Color.blue.opacity(0.6) : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
        )
        .padding()
        .onDrop(of: Self.acceptedTypes, isTargeted: self.$isDraggingOver) { providers in
            self.handleDrop(providers)
        }
    }

    // MARK: - Programmatic entry point

    /// Open the sheet for a given URL directly (e.g. from menu command).
    public func load(url: URL) {
        Task {
            await self.viewModel.load(appURL: url)
            if self.viewModel.scanState == .ready {
                self.isSheetPresented = true
            }
        }
    }

    // MARK: - Drop handling

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            Task { @MainActor in
                await self.viewModel.load(appURL: url)
                if self.viewModel.scanState == .ready {
                    self.isSheetPresented = true
                }
            }
        }
        return true
    }
}
