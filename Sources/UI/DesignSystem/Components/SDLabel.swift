import SwiftUI

public struct SDLabel: View {
    private let text: String
    private let variant: SDLabelVariant

    @Environment(\.theme) private var theme

    public init(_ text: String, variant: SDLabelVariant = .primary) {
        self.text = text
        self.variant = variant
    }

    private var font: Font {
        switch self.variant {
        case .primary: self.theme.typography.body
        case .secondary: self.theme.typography.body
        case .caption: self.theme.typography.caption
        case .mono: self.theme.typography.mono
        }
    }

    private var color: Color {
        switch self.variant {
        case .primary: self.theme.colors.textPrimary
        case .secondary: self.theme.colors.textSecondary
        case .caption: self.theme.colors.textSecondary
        case .mono: self.theme.colors.textPrimary
        }
    }

    public var body: some View {
        Text(self.text)
            .font(self.font)
            .foregroundStyle(self.color)
    }
}
