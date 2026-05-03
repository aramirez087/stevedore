import Core
import DesignSystem
import FeaturesOperations
import SwiftUI
import UIMenus
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
            Sidebar(viewModel: self.model.sidebarViewModel)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            VStack(spacing: 0) {
                self.dualPane
                if !self.model.activeOperations.isEmpty {
                    Divider()
                    TransfersPanel(operations: self.model.activeOperations)
                        .frame(height: 140)
                        .transition(.move(edge: .bottom))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: self.model.activeOperations.isEmpty)
        }
        .frame(minWidth: 800, minHeight: 500)
        .focusedValue(\.windowCommandProxy, self.buildWindowProxy())
        .sheet(isPresented: self.$model.showConnectDialog) {
            Text("Connect to Server\u{2026}")
                .padding()
        }
        .sheet(isPresented: self.$model.showSyncDialog) {
            Text("Compare/Sync Folders\u{2026}")
                .padding()
        }
        .sheet(isPresented: self.$model.showRenameDialog) {
            Text("Multi-Rename\u{2026}")
                .padding()
        }
        .sheet(isPresented: self.$model.showUninstallerDialog) {
            Text("Application Uninstaller\u{2026}")
                .padding()
        }
        .task { await self.model.restore() }
        .onChange(of: self.model.sidebarViewModel.selection) { _, newValue in
            self.routeSidebarSelection(newValue)
        }
    }

    // MARK: - Dual pane

    private var dualPane: some View {
        DualPaneLayout(splitFraction: Binding(
            get: { self.model.windowState.splitFraction },
            set: { self.model.windowState.splitFraction = $0 }
        )) {
            PaneHost(
                session: self.model.leftSession,
                isActive: self.model.windowState.activePaneID == .left,
                onActivate: { self.model.windowState.activePaneID = .left },
                onDropped: { self.model.handleDrop($0, onto: .left) }
            )
        } right: {
            PaneHost(
                session: self.model.rightSession,
                isActive: self.model.windowState.activePaneID == .right,
                onActivate: { self.model.windowState.activePaneID = .right },
                onDropped: { self.model.handleDrop($0, onto: .right) }
            )
        }
    }

    // MARK: - Sidebar routing

    private func routeSidebarSelection(_ id: SidebarItemID?) {
        guard let id, let path = filePath(for: id) else { return }
        self.model.activePaneSession.navigate(to: path)
    }

    private func filePath(for id: SidebarItemID) -> FilePath? {
        switch id {
        case .volume(let url):
            FilePath(scheme: .local, posix: url.path)
        case .bookmark(let bookmarkID):
            self.model.sidebarViewModel.bookmarks.bookmarks
                .first { $0.id == bookmarkID }
                .map(\.path)
        case .connection, .tag:
            nil
        }
    }

    private func buildWindowProxy() -> WindowCommandProxy {
        WindowCommandProxy(
            showConnectDialog: { [m = model] in m.showConnectDialog = true },
            showSyncDialog: { [m = model] in m.showSyncDialog = true },
            showRenameDialog: { [m = model] in m.showRenameDialog = true },
            showUninstallerDialog: { [m = model] in m.showUninstallerDialog = true },
            focusSearch: {}
        )
    }
}
