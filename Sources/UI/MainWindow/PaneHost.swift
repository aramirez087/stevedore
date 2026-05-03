import Core
import DesignSystem
import Foundation
import SwiftUI
import UIMenus
import UIToolbar

/// Per-pane composition: PaneToolbar + minimal tab strip + content placeholder.
///
/// UIPane and UITabs (Sessions 16 & 17) are still stub modules; this file provides
/// inline minimal views that make the window functional and testable.
/// Drop on this pane converts URLs to FilePaths and delegates to `onDropped`.
public struct PaneHost: View {
    @Bindable var session: PaneSession
    var isActive: Bool
    var onActivate: () -> Void
    var onDropped: ([FilePath]) -> Void

    @Environment(\.theme) private var theme

    public init(
        session: PaneSession,
        isActive: Bool,
        onActivate: @escaping () -> Void,
        onDropped: @escaping ([FilePath]) -> Void
    ) {
        self.session = session
        self.isActive = isActive
        self.onActivate = onActivate
        self.onDropped = onDropped
    }

    public var body: some View {
        VStack(spacing: 0) {
            PaneToolbar(viewModel: self.session.toolbarViewModel)
            PaneTabStrip(session: self.session)
            Divider()
            FileBrowserView(session: self.session)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(self.activeBorder)
        .contentShape(Rectangle())
        .onTapGesture { self.onActivate() }
        .dropDestination(for: URL.self) { urls, _ in
            let paths = urls.map { FilePath(scheme: .local, posix: $0.path) }
            self.onDropped(paths)
            return !paths.isEmpty
        }
        .focusedValue(\.paneCommandProxy, self.isActive ? self.buildProxy() : nil)
    }

    private var activeBorder: some View {
        Rectangle().strokeBorder(
            self.isActive ? Color.accentColor : Color.clear,
            lineWidth: 2
        )
    }

    private func buildProxy() -> PaneCommandProxy {
        let session = self.session
        return PaneCommandProxy(
            currentPath: session.currentPath,
            canGoBack: session.toolbarViewModel.canGoBack,
            canGoForward: session.toolbarViewModel.canGoForward,
            isRemoteReadOnly: session.currentPath.scheme != .local,
            goBack: { session.toolbarViewModel.goBack() },
            goForward: { session.toolbarViewModel.goForward() },
            goUp: {
                let parent = (session.currentPath.posixString as NSString)
                    .deletingLastPathComponent
                session.navigate(to: FilePath(scheme: session.currentPath.scheme, posix: parent))
            },
            goHome: {
                session.navigate(to: FilePath(scheme: .local, posix: NSHomeDirectory()))
            },
            goToComputer: {
                session.navigate(to: FilePath(scheme: .local, posix: "/"))
            },
            newFolder: {},
            newFile: {},
            open: {},
            openWith: {},
            moveToTrash: {},
            compress: {},
            decompress: {},
            toggleHiddenFiles: {},
            refresh: {},
            openInTerminal: {
                OpenInTerminal.launch(path: session.currentPath, using: "")
            },
            openNewTab: { session.openTab(at: session.currentPath) },
            closeActiveTab: {
                guard let tabID = session.activeTabID else { return }
                session.closeTab(tabID)
            },
            reopenClosedTab: {},
            nextTab: {
                guard let cur = session.activeTabID,
                      let idx = session.tabs.firstIndex(where: { $0.id == cur }),
                      idx + 1 < session.tabs.count else { return }
                session.activateTab(session.tabs[idx + 1].id)
            },
            previousTab: {
                guard let cur = session.activeTabID,
                      let idx = session.tabs.firstIndex(where: { $0.id == cur }),
                      idx > 0 else { return }
                session.activateTab(session.tabs[idx - 1].id)
            },
            selectAll: {},
            sortByName: {},
            sortByDateModified: {},
            sortBySize: {},
            sortByKind: {}
        )
    }
}

// MARK: - PaneTabStrip

/// Minimal tab strip — full implementation deferred to UITabs (Session 17).
private struct PaneTabStrip: View {
    @Bindable var session: PaneSession
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(self.session.tabs, id: \.id) { tab in
                    PaneTabButton(
                        tab: tab,
                        isActive: tab.id == self.session.activeTabID,
                        onActivate: { self.session.activateTab(tab.id) },
                        onClose: { self.session.closeTab(tab.id) }
                    )
                }
            }
        }
        .background(self.theme.colors.surface)
        .frame(height: 30)
    }
}

private struct PaneTabButton: View {
    let tab: Core.Tab
    let isActive: Bool
    let onActivate: () -> Void
    let onClose: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(self.tab.title ?? self.tab.path.lastComponent ?? "/")
                .font(self.theme.typography.caption)
                .foregroundStyle(self.isActive ? self.theme.colors.textPrimary : self.theme.colors.textSecondary)
                .lineLimit(1)
            Button(action: self.onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundStyle(self.theme.colors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(self.isActive ? self.theme.colors.background : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { self.onActivate() }
    }
}

// MARK: - FileBrowserView

/// Observes `session` directly so path changes (sidebar clicks, toolbar nav, in-pane
/// folder clicks) all update this view without relying on PaneHost to re-render first.
private struct FileBrowserView: View {
    @Bindable var session: PaneSession

    @State private var items: [FileItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            self.theme.colors.background.ignoresSafeArea()
            if self.isLoading {
                ProgressView()
            } else if self.items.isEmpty {
                VStack(spacing: Spacing.sm) {
                    if let msg = self.errorMessage {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundStyle(self.theme.colors.textSecondary)
                        Text(msg)
                            .font(self.theme.typography.caption)
                            .foregroundStyle(self.theme.colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.md)
                    } else {
                        Text("Empty folder")
                            .font(self.theme.typography.caption)
                            .foregroundStyle(self.theme.colors.textSecondary)
                        Text("Hidden items are not shown")
                            .font(self.theme.typography.caption)
                            .foregroundStyle(self.theme.colors.textSecondary.opacity(0.6))
                    }
                }
            } else {
                List(self.items, id: \.path) { item in
                    HStack(spacing: Spacing.sm) {
                        FileKindIcon(
                            kind: item.kind,
                            fileExtension: {
                                let ext = (item.displayName as NSString).pathExtension
                                return ext.isEmpty ? nil : ext
                            }(),
                            size: .sm
                        )
                        Text(item.displayName)
                            .font(self.theme.typography.body)
                            .foregroundStyle(self.theme.colors.textPrimary)
                        Spacer()
                        if item.kind != .directory, let bytes = item.attributes.sizeInBytes {
                            Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                                .font(self.theme.typography.caption)
                                .foregroundStyle(self.theme.colors.textSecondary)
                                .frame(width: 80, alignment: .trailing)
                        }
                        if let date = item.attributes.modificationDate {
                            Text(date, style: .date)
                                .font(self.theme.typography.caption)
                                .foregroundStyle(self.theme.colors.textSecondary)
                                .frame(width: 90, alignment: .trailing)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if item.kind == .directory {
                            self.session.navigate(to: item.path)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .task(id: self.session.currentPath) {
            await self.loadItems()
        }
    }

    private func loadItems() async {
        self.isLoading = true
        self.errorMessage = nil
        var collected: [FileItem] = []
        do {
            for try await item in self.session.provider.enumerate(
                at: self.session.currentPath,
                options: .default
            ) {
                collected.append(item)
                if Task.isCancelled { break }
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        self.items = collected.sorted {
            if $0.kind == .directory && $1.kind != .directory { return true }
            if $0.kind != .directory && $1.kind == .directory { return false }
            return $0.displayName.localizedCompare($1.displayName) == .orderedAscending
        }
        self.isLoading = false
    }
}
