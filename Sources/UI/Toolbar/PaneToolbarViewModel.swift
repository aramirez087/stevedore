import Core
import Observation

/// Drives the per-pane toolbar and path bar.
///
/// All navigation and action side-effects are routed through callback
/// properties — the view-model itself performs no FS or network access.
/// The shell (Session 26) must wire each callback before embedding `PaneToolbar`.
@MainActor
@Observable
public final class PaneToolbarViewModel {
    public private(set) var currentPath: FilePath
    public var viewMode: ViewMode = .list
    public private(set) var history: HistoryStack
    public let searchDebouncer: SearchDebouncer

    // MARK: Callbacks — shell must wire these

    /// Called after every successful navigation (back, forward, up, or direct).
    public var onNavigate: ((FilePath) -> Void)?
    /// Called when the user taps the refresh button.
    public var onRefresh: (() -> Void)?
    /// Called when the user taps the new-folder button.
    public var onNewFolder: (() -> Void)?
    /// Called when the user selects `.columns` or `.icons` (not yet implemented in MVP).
    public var onViewModeUnavailable: ((ViewMode) -> Void)?

    // MARK: Derived state

    public var canGoBack: Bool {
        self.history.canGoBack
    }

    public var canGoForward: Bool {
        self.history.canGoForward
    }

    public var canGoUp: Bool {
        !self.currentPath.isRoot
    }

    // MARK: Init

    public init(
        initialPath: FilePath,
        historyCapacity: Int = HistoryStack.defaultCapacity,
        searchDebouncer: SearchDebouncer? = nil
    ) {
        self.currentPath = initialPath
        self.history = HistoryStack(capacity: historyCapacity)
        self.searchDebouncer = searchDebouncer ?? SearchDebouncer()
        self.history.navigate(to: initialPath)
    }

    // MARK: Actions

    /// Navigate to a new path; clears forward history.
    public func navigate(to path: FilePath) {
        self.history.navigate(to: path)
        self.currentPath = path
        self.onNavigate?(path)
    }

    public func goBack() {
        guard let path = history.goBack() else { return }
        self.currentPath = path
        self.onNavigate?(path)
    }

    public func goForward() {
        guard let path = history.goForward() else { return }
        self.currentPath = path
        self.onNavigate?(path)
    }

    public func goUp() {
        guard let parent = currentPath.parent else { return }
        self.navigate(to: parent)
    }

    public func refresh() {
        self.onRefresh?()
    }

    public func newFolder() {
        self.onNewFolder?()
    }

    /// Sets view mode. Only `.list` is wired in MVP; others call `onViewModeUnavailable`.
    public func setViewMode(_ mode: ViewMode) {
        if mode == .list {
            self.viewMode = mode
        } else {
            self.onViewModeUnavailable?(mode)
        }
    }
}
