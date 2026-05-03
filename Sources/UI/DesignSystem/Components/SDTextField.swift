import SwiftUI

public struct SDTextField: View {
    private let placeholder: String
    @Binding private var text: String

    @Environment(\.theme) private var theme

    public init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    public var body: some View {
        TextField(self.placeholder, text: self.$text)
            .textFieldStyle(.plain)
            .font(self.theme.typography.body)
            .foregroundStyle(self.theme.colors.textPrimary)
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(self.theme.colors.divider, lineWidth: 1)
            )
    }
}
