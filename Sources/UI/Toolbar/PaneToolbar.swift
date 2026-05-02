import Core
import DesignSystem
import SwiftUI

/// Full per-pane toolbar: back/forward/up navigation, view-mode picker,
/// search field, refresh and new-folder actions, and the breadcrumb path bar.
public struct PaneToolbar: View {
    @Bindable private var viewModel: PaneToolbarViewModel

    @Environment(\.theme) private var theme

    public init(viewModel: PaneToolbarViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                self.navButtons
                Divider().frame(height: 16)
                self.viewModePicker
                Spacer()
                SearchField(debouncer: self.viewModel.searchDebouncer)
                    .frame(width: 180)
                self.actionButtons
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(self.theme.colors.surface)

            Divider()

            PathBar(
                path: self.viewModel.currentPath,
                onNavigate: { self.viewModel.navigate(to: $0) }
            )

            Divider()
        }
    }

    private var navButtons: some View {
        HStack(spacing: Spacing.xs) {
            self.toolbarButton(systemName: "chevron.left", disabled: !self.viewModel.canGoBack) {
                self.viewModel.goBack()
            }
            self.toolbarButton(systemName: "chevron.right", disabled: !self.viewModel.canGoForward) {
                self.viewModel.goForward()
            }
            self.toolbarButton(systemName: "arrow.up", disabled: !self.viewModel.canGoUp) {
                self.viewModel.goUp()
            }
        }
    }

    private var viewModePicker: some View {
        HStack(spacing: 0) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button { self.viewModel.setViewMode(mode) } label: {
                    Image(systemName: self.viewModeIcon(for: mode))
                        .foregroundStyle(
                            self.viewModel.viewMode == mode
                                ? self.theme.colors.accent
                                : self.theme.colors.textSecondary
                        )
                }
                .buttonStyle(.plain)
                .padding(Spacing.xs)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: Spacing.xs) {
            self.toolbarButton(systemName: "arrow.clockwise") { self.viewModel.refresh() }
            self.toolbarButton(systemName: "folder.badge.plus") { self.viewModel.newFolder() }
        }
    }

    private func toolbarButton(
        systemName: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(disabled ? self.theme.colors.textSecondary : self.theme.colors.textPrimary)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func viewModeIcon(for mode: ViewMode) -> String {
        switch mode {
        case .list: "list.bullet"
        case .columns: "rectangle.split.3x1"
        case .icons: "square.grid.2x2"
        }
    }
}
