import Core
import DesignSystem
import SwiftUI
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
            PaneContentPlaceholder(path: self.session.currentPath)
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
    }

    private var activeBorder: some View {
        Rectangle().strokeBorder(
            self.isActive ? Color.accentColor : Color.clear,
            lineWidth: 2
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

// MARK: - PaneContentPlaceholder

/// Minimal content area — full implementation deferred to UIPane (Session 16).
private struct PaneContentPlaceholder: View {
    let path: FilePath
    @Environment(\.theme) private var theme

    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundStyle(self.theme.colors.textSecondary)
            Text(self.path.posixString)
                .font(self.theme.typography.caption)
                .foregroundStyle(self.theme.colors.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, Spacing.md)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(self.theme.colors.background)
    }
}
