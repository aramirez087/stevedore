import Core
import SwiftUI
import UniformTypeIdentifiers

/// Lists saved remote host descriptors with a live status indicator.
struct ConnectionsSection: View {
    @Bindable var viewModel: SidebarViewModel

    var body: some View {
        Section("Remote") {
            ForEach(self.viewModel.connectionStatus.descriptors) { descriptor in
                HStack {
                    SidebarRow(
                        title: descriptor.displayName,
                        symbolName: self.schemeSymbol(descriptor.scheme)
                    )
                    .tag(SidebarItemID.connection(descriptor.id))
                    self.statusView(for: self.viewModel.connectionStatus.status(for: descriptor.id))
                }
                .contextMenu {
                    Button("Remove") {
                        self.viewModel.connectionStatus.remove(id: descriptor.id)
                    }
                }
            }
        }
        // Drop stub — full RemoteHostDescriptor JSON drop wired in Session 26.
        .onDrop(of: [UTType.json], isTargeted: nil) { _ in false }
    }

    // MARK: - Helpers

    private func schemeSymbol(_ scheme: ConnectionScheme) -> String {
        let map: [ConnectionScheme: String] = [
            .sftp: "server.rack",
            .ftp: "server.rack",
            .webdav: "globe",
            .s3: "cloud",
            .smb: "network",
        ]
        return map[scheme] ?? "network"
    }

    @ViewBuilder
    private func statusView(for status: ConnectionStatus) -> some View {
        let (symbol, color) = self.statusInfo(status)
        Image(systemName: symbol)
            .foregroundStyle(color)
            .imageScale(.small)
    }

    private func statusInfo(_ status: ConnectionStatus) -> (String, Color) {
        switch status {
        case .idle: ("circle", .secondary)
        case .connecting: ("arrow.circlepath", .orange)
        case .connected: ("circle.fill", .green)
        case .error: ("exclamationmark.circle", .red)
        }
    }
}
