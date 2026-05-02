import Core
import FeaturesOperations
import Foundation
import Observation
import ServicesSettings
import UISidebar

/// Owns all window state and coordinates the sidebar, two pane sessions, and operation queue.
///
/// Constructed once by `AppEnvironment` and passed into `MainWindowView`.
/// Persists state via `WorkspacesRepository`; the current session is saved as the
/// last `Workspace` entry.
@MainActor
@Observable
public final class MainWindowModel {
    public let operationQueue: FileOperationQueue
    public let sidebarViewModel: SidebarViewModel
    public let windowState: WindowState
    public let leftSession: PaneSession
    public let rightSession: PaneSession

    /// Current queue snapshot; updated from `operationQueue.operationStream()`.
    public private(set) var activeOperations: [FeaturesOperations.Operation] = []

    @ObservationIgnored private let repository: WorkspacesRepository?
    @ObservationIgnored private var streamTask: Task<Void, Never>?

    public var activePaneSession: PaneSession {
        windowState.activePaneID == .left ? leftSession : rightSession
    }

    public init(
        operationQueue: FileOperationQueue,
        sidebarViewModel: SidebarViewModel,
        windowState: WindowState,
        leftSession: PaneSession,
        rightSession: PaneSession,
        repository: WorkspacesRepository? = nil
    ) {
        self.operationQueue = operationQueue
        self.sidebarViewModel = sidebarViewModel
        self.windowState = windowState
        self.leftSession = leftSession
        self.rightSession = rightSession
        self.repository = repository
    }

    deinit {
        streamTask?.cancel()
    }

    // MARK: - Lifecycle

    /// Restores persisted window state and begins observing the operation queue.
    public func restore() async {
        startObserving()
        guard let repo = repository else { return }
        let workspaces = await repo.all()
        if let latest = workspaces.last {
            applySnapshot(from: latest)
        }
    }

    /// Persists the current window state as the latest workspace.
    public func save() async throws {
        guard let repo = repository else { return }
        let workspace = buildWorkspace()
        try await repo.save([workspace])
    }

    // MARK: - Cross-pane drop

    /// Routes a drop of paths from the opposite pane as a copy operation.
    public func handleDrop(_ paths: [FilePath], onto targetID: PaneID) {
        let dest = (targetID == .left ? leftSession : rightSession).currentPath
        let descriptor = OperationDescriptor(
            kind: .copy,
            sources: paths,
            destination: dest
        )
        Task { await operationQueue.enqueue(descriptor) }
    }

    // MARK: - Private

    private func startObserving() {
        guard streamTask == nil else { return }
        streamTask = Task { [weak self, queue = operationQueue] in
            for await ops in queue.operationStream() {
                guard let self else { break }
                self.activeOperations = ops
            }
        }
    }

    private func applySnapshot(from workspace: Workspace) {
        // Restore split fraction.
        // Tabs and paths are stored in WorkspacePane; navigate each pane to its last path.
        if let leftActive = workspace.leftPane.tabs.first(where: { $0.id == workspace.leftPane.activeTabID }),
           leftSession.tabs.isEmpty == false {
            leftSession.navigate(to: leftActive.path)
        }
        if let rightActive = workspace.rightPane.tabs.first(where: { $0.id == workspace.rightPane.activeTabID }),
           rightSession.tabs.isEmpty == false {
            rightSession.navigate(to: rightActive.path)
        }
    }

    private func buildWorkspace() -> Workspace {
        let leftPane = WorkspacePane(
            tabs: leftSession.tabs,
            activeTabID: leftSession.activeTabID
        )
        let rightPane = WorkspacePane(
            tabs: rightSession.tabs,
            activeTabID: rightSession.activeTabID
        )
        return Workspace(leftPane: leftPane, rightPane: rightPane)
    }
}
