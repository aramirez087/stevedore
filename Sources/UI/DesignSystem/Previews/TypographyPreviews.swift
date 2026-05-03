import SwiftUI

#Preview("Typography – Light") {
    TypographyPreviewContent()
        .preferredColorScheme(.light)
        .padding(Spacing.md)
}

#Preview("Typography – Dark") {
    TypographyPreviewContent()
        .preferredColorScheme(.dark)
        .padding(Spacing.md)
}

private struct TypographyPreviewContent: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Large Title — 26pt Bold")
                .font(self.theme.typography.largeTitle)
                .foregroundStyle(self.theme.colors.textPrimary)
            Text("Title — 20pt Semibold")
                .font(self.theme.typography.title)
                .foregroundStyle(self.theme.colors.textPrimary)
            Text("Body — 13pt Regular")
                .font(self.theme.typography.body)
                .foregroundStyle(self.theme.colors.textPrimary)
            Text("Caption — 11pt Regular")
                .font(self.theme.typography.caption)
                .foregroundStyle(self.theme.colors.textSecondary)
            Text("Mono — 13pt SF Mono")
                .font(self.theme.typography.mono)
                .foregroundStyle(self.theme.colors.textPrimary)
        }
    }
}
