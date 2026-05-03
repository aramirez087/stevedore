import Core
import Foundation
import Observation
import UIToolbar

/// Per-pane view model: owns the active provider, current path, history, and tab list.
///
/// All external navigations (sidebar clicks, double-clicks, etc.) must go through
/// `navigate(to:)` which delegates to the toolbar view model to keep history in sync.
/// The private `updatePath(to:)` method updates state WITHOUT calling the toolbar back,
/// breaking the `navigate → onNavigate → navigate` infinite-loop cycle.
@MainActor
@Observable
public final class PaneSession {
    public let id: PaneID
    public private(set) var currentPath: FilePath
    public private(set) var tabs: [Tab]
    public private(set) var activeTabID: Tab.ID?

    @ObservationIgnored public let provider: any FileSystemProvider
    @ObservationIgnored public let toolbarViewModel: PaneToolbarViewModel

    public init(id: PaneID, initialPath: FilePath, provider: any FileSystemProvider) {
        self.id = id
        self.currentPath = initialPath
        self.provider = provider
        let firstTab = Tab(path: initialPath)
        self.tabs = [firstTab]
        self.activeTabID = firstTab.id
        self.toolbarViewModel = PaneToolbarViewModel(initialPath: initialPath)
        // Wire toolbar callback. updatePath must NOT call toolbar back to avoid reentrancy.
        self.toolbarViewModel.onNavigate = { [weak self] path in
            self?.updatePath(to: path)
        }
    }

    // MARK: - Navigation

    /// All external navigations route through here to keep back/forward history in sync.
    public func navigate(to path: FilePath) {
        self.toolbarViewModel.navigate(to: path)
    }

    // MARK: - Navigation convenience (delegates to toolbarViewModel)

    public var canGoBack: Bool {
        self.toolbarViewModel.canGoBack
    }

    public var canGoForward: Bool {
        self.toolbarViewModel.canGoForward
    }

    public func goBack() {
        self.toolbarViewModel.goBack()
    }

    public func goForward() {
        self.toolbarViewModel.goForward()
    }

    public func goUp() {
        self.toolbarViewModel.goUp()
    }

    public func goHome() {
        self.navigate(to: FilePath(
            scheme: .local,
            posix: FileManager.default.homeDirectoryForCurrentUser.path
        ))
    }

    public func goToComputer() {
        self.navigate(to: FilePath(scheme: .local, posix: "/"))
    }

    // MARK: - Tab management

    public func openTab(at path: FilePath) {
        let tab = Tab(path: path)
        self.tabs.append(tab)
        self.activateTab(tab.id)
    }

    public func closeTab(_ tabID: Tab.ID) {
        guard self.tabs.count > 1 else { return }
        self.tabs.removeAll { $0.id == tabID }
        if self.activeTabID == tabID {
            self.activeTabID = self.tabs.last?.id
            if let path = tabs.last?.path {
                self.toolbarViewModel.navigate(to: path)
            }
        }
    }

    public func activateTab(_ tabID: Tab.ID) {
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return }
        self.activeTabID = tabID
        self.navigate(to: tab.path)
    }

    // MARK: - Private

    /// Updates `currentPath` and the active tab path. Must NOT call `navigate(to:)` or
    /// `toolbarViewModel.navigate(to:)` — only called from `toolbarViewModel.onNavigate`.
    private func updatePath(to path: FilePath) {
        self.currentPath = path
        if let idx = tabs.firstIndex(where: { $0.id == activeTabID }) {
            self.tabs[idx] = Tab(id: self.tabs[idx].id, path: path, title: self.tabs[idx].title)
        }
    }
}
