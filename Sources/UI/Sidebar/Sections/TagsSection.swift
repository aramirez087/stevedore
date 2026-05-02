import SwiftUI

/// Read-only list of Finder tag names loaded by `SidebarViewModel.start()`.
struct TagsSection: View {
    @Bindable var viewModel: SidebarViewModel

    var body: some View {
        Section("Tags") {
            ForEach(self.viewModel.tags, id: \.self) { tag in
                SidebarRow(title: tag, symbolName: "tag")
                    .tag(SidebarItemID.tag(tag))
            }
        }
    }
}
