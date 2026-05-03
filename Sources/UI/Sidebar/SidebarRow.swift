import DesignSystem
import SwiftUI

/// Shared row for all sidebar sections: icon + title styled with design-system tokens.
struct SidebarRow: View {
    let title: String
    let symbolName: String

    @Environment(\.theme) private var theme

    var body: some View {
        Label(self.title, systemImage: self.symbolName)
            .font(self.theme.typography.body)
            .foregroundStyle(self.theme.colors.textPrimary)
    }
}
