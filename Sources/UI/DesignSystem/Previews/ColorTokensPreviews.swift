import SwiftUI

#Preview("ColorTokens – Light") {
    ColorTokensPreviewContent()
        .preferredColorScheme(.light)
        .padding(Spacing.md)
}

#Preview("ColorTokens – Dark") {
    ColorTokensPreviewContent()
        .preferredColorScheme(.dark)
        .padding(Spacing.md)
}

private struct ColorTokensPreviewContent: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ColorSwatchRow(name: "background", color: self.theme.colors.background)
            ColorSwatchRow(name: "surface", color: self.theme.colors.surface)
            ColorSwatchRow(name: "surfaceElevated", color: self.theme.colors.surfaceElevated)
            ColorSwatchRow(name: "textPrimary", color: self.theme.colors.textPrimary)
            ColorSwatchRow(name: "textSecondary", color: self.theme.colors.textSecondary)
            ColorSwatchRow(name: "accent", color: self.theme.colors.accent)
            ColorSwatchRow(name: "danger", color: self.theme.colors.danger)
            ColorSwatchRow(name: "success", color: self.theme.colors.success)
            ColorSwatchRow(name: "divider", color: self.theme.colors.divider)
        }
    }
}

private struct ColorSwatchRow: View {
    let name: String
    let color: Color

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: 4)
                .fill(self.color)
                .frame(width: 32, height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(self.theme.colors.divider, lineWidth: 1)
                )
            Text(self.name)
                .font(self.theme.typography.body)
                .foregroundStyle(self.theme.colors.textPrimary)
        }
    }
}
