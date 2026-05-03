/// The three display modes available for a file-list pane.
///
/// Only `.list` is wired in MVP; `.columns` and `.icons` emit a delegate
/// notification via `PaneToolbarViewModel.onViewModeUnavailable`.
public enum ViewMode: String, Sendable, CaseIterable {
    case list
    case columns
    case icons
}
