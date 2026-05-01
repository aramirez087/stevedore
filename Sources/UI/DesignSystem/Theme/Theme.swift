import SwiftUI

public struct Theme: Sendable {
    public let colors: ColorTokens
    public let typography: Typography

    public static let system = Self(
        colors: .system,
        typography: .system
    )
}

public extension EnvironmentValues {
    @Entry var theme: Theme = .system
}

public extension View {
    func theme(_ theme: Theme) -> some View {
        self.environment(\.theme, theme)
    }
}
