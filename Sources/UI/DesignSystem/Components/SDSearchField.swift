import SwiftUI

public struct SDSearchField: View {
    @Binding private var text: String

    @Environment(\.theme) private var theme

    public init(text: Binding<String>) {
        self._text = text
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(self.theme.colors.textSecondary)
            TextField("Search", text: self.$text)
                .textFieldStyle(.plain)
                .font(self.theme.typography.body)
                .foregroundStyle(self.theme.colors.textPrimary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(self.theme.colors.surface)
        )
    }
}
