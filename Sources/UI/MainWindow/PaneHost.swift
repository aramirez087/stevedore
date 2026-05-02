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
            PaneToolbar(viewModel: session.toolbarViewModel)
            PaneTabStrip(session: session)
            Divider()
            PaneContentPlaceholder(path: session.currentPath)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(activeBorder)
        .contentShape(Rectangle())
        .onTapGesture { onActivate() }
        .dropDestination(for: URL.self) { urls, _ in
            let paths = urls.map { FilePath(scheme: .local, posix: $0.path) }
            onDropped(paths)
            return !paths.isEmpty
        }
    }

    private var activeBorder: some View {
        Rectangle().strokeBorder(
            isActive ? Color.accentColor : Color.clear,
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
                ForEach(session.tabs, id: \.id) { tab in
                    PaneTabButton(
                        tab: tab,
                        isActive: tab.id == session.activeTabID,
                        onActivate: { session.activateTab(tab.id) },
                        onClose: { session.closeTab(tab.id) }
                    )
                }
            }
        }
        .background(theme.colors.surface)
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
            Text(tab.title ?? tab.path.lastComponent ?? "/")
                .font(theme.typography.caption)
                .foregroundStyle(isActive ? theme.colors.textPrimary : theme.colors.textSecondary)
                .lineLimit(1)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(isActive ? theme.colors.background : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onActivate() }
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
                .foregroundStyle(theme.colors.textSecondary)
            Text(path.posixString)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, Spacing.md)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.background)
    }
}
