import DesignSystem
import SwiftUI

/// Lists mounted volumes; shows an eject button for ejectable disks.
struct DevicesSection: View {
    @Bindable var viewModel: SidebarViewModel

    var body: some View {
        Section("Devices") {
            ForEach(self.viewModel.volumes) { volume in
                HStack {
                    SidebarRow(
                        title: volume.name,
                        symbolName: volume.isRemovable
                            ? "externaldrive.connected.to.line.below"
                            : "internaldrive"
                    )
                    if volume.isEjectable {
                        Spacer()
                        Button {
                            Task { await self.viewModel.ejectVolume(url: volume.url) }
                        } label: {
                            Image(systemName: "eject")
                                .imageScale(.small)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .tag(SidebarItemID.volume(volume.url))
            }
        }
    }
}
