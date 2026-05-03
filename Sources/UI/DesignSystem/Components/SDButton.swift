import SwiftUI

public struct SDButton: View {
    private let label: String
    private let style: SDButtonStyle
    private let action: () -> Void

    @Environment(\.theme) private var theme

    public init(_ label: String, style: SDButtonStyle = .primary, action: @escaping () -> Void) {
        self.label = label
        self.style = style
        self.action = action
    }

    private var backgroundColor: Color {
        switch self.style {
        case .primary: self.theme.colors.accent
        case .secondary: self.theme.colors.surface
        case .destructive: self.theme.colors.danger
        }
    }

    private var foregroundColor: Color {
        switch self.style {
        case .primary: self.theme.colors.textOnAccent
        case .secondary: self.theme.colors.textPrimary
        case .destructive: self.theme.colors.textOnAccent
        }
    }

    public var body: some View {
        Button(action: self.action) {
            Text(self.label)
                .font(self.theme.typography.body)
                .foregroundStyle(self.foregroundColor)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(self.backgroundColor)
                )
        }
        .buttonStyle(.plain)
    }
}
