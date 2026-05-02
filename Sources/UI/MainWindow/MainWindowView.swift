import Core
import DesignSystem
import FeaturesOperations
import SwiftUI
import UISidebar

/// Top-level window view: sidebar + dual panes + optional transfers panel.
///
/// Sidebar selection is routed to the active pane via `.onChange(of:)`.
/// The transfers panel auto-shows (with a slide-up animation) when the queue is non-empty.
public struct MainWindowView: View {
    @Bindable var model: MainWindowModel

    public init(model: MainWindowModel) {
        self.model = model
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            Sidebar(viewModel: model.sidebarViewModel)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            VStack(spacing: 0) {
                dualPane
                if !model.activeOperations.isEmpty {
                    Divider()
                    TransfersPanel(operations: model.activeOperations)
                        .frame(height: 140)
                        .transition(.move(edge: .bottom))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: model.activeOperations.isEmpty)
        }
        .frame(minWidth: 800, minHeight: 500)
        .task { await model.restore() }
        .onChange(of: model.sidebarViewModel.selection) { _, newValue in
            routeSidebarSelection(newValue)
        }
    }

    // MARK: - Dual pane

    private var dualPane: some View {
        DualPaneLayout(splitFraction: Binding(
            get: { model.windowState.splitFraction },
            set: { model.windowState.splitFraction = $0 }
        )) {
            PaneHost(
                session: model.leftSession,
                isActive: model.windowState.activePaneID == .left,
                onActivate: { model.windowState.activePaneID = .left },
                onDropped: { model.handleDrop($0, onto: .left) }
            )
        } right: {
            PaneHost(
                session: model.rightSession,
                isActive: model.windowState.activePaneID == .right,
                onActivate: { model.windowState.activePaneID = .right },
                onDropped: { model.handleDrop($0, onto: .right) }
            )
        }
    }

    // MARK: - Sidebar routing

    private func routeSidebarSelection(_ id: SidebarItemID?) {
        guard let id, let path = filePath(for: id) else { return }
        model.activePaneSession.navigate(to: path)
    }

    private func filePath(for id: SidebarItemID) -> FilePath? {
        switch id {
        case .volume(let url):
            return FilePath(scheme: .local, posix: url.path)
        case .bookmark(let bookmarkID):
            return model.sidebarViewModel.bookmarks.bookmarks
                .first { $0.id == bookmarkID }
                .map(\.path)
        case .connection, .tag:
            return nil
        }
    }
}
