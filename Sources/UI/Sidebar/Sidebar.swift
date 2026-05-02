import DesignSystem
import SwiftUI

/// Top-level sidebar view composing the four sections.
///
/// Place this view inside a `NavigationSplitView` sidebar column.
/// The selection binding routes to the active pane's path via the parent window shell.
public struct Sidebar: View {
    @Bindable var viewModel: SidebarViewModel

    public init(viewModel: SidebarViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        List(selection: Binding(
            get: { self.viewModel.selection },
            set: { self.viewModel.select($0) }
        )) {
            FavoritesSection(viewModel: self.viewModel)
            DevicesSection(viewModel: self.viewModel)
            ConnectionsSection(viewModel: self.viewModel)
            TagsSection(viewModel: self.viewModel)
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180, idealWidth: 220)
        .task { await self.viewModel.start() }
    }
}
