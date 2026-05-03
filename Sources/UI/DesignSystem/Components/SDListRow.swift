import SwiftUI

public struct SDListRow: View {
    private let content: SDListRowContent
    private let symbolName: String?
    private let isSelected: Bool

    @Environment(\.theme) private var theme

    public init(content: SDListRowContent, symbolName: String? = nil, isSelected: Bool = false) {
        self.content = content
        self.symbolName = symbolName
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            if let name = self.symbolName {
                Image(systemName: name)
                    .frame(width: 16, height: 16)
                    .foregroundStyle(self.theme.colors.textSecondary)
            }
            self.contentView
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            self.isSelected
                ? self.theme.colors.accent.opacity(0.15)
                : Color.clear
        )
    }

    @ViewBuilder
    private var contentView: some View {
        switch self.content {
        case .singleLine(let title):
            Text(title)
                .font(self.theme.typography.body)
                .foregroundStyle(self.theme.colors.textPrimary)
        case .doubleLine(let title, let subtitle):
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(self.theme.typography.body)
                    .foregroundStyle(self.theme.colors.textPrimary)
                Text(subtitle)
                    .font(self.theme.typography.caption)
                    .foregroundStyle(self.theme.colors.textSecondary)
            }
        }
    }
}
