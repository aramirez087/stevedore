import AppKit
import SwiftUI

public struct ColorTokens: Sendable {
    public let background: Color
    public let surface: Color
    public let surfaceElevated: Color
    public let textPrimary: Color
    public let textSecondary: Color
    public let accent: Color
    public let danger: Color
    public let success: Color
    public let divider: Color
    /// White text for use on accent- and danger-colored backgrounds.
    public let textOnAccent: Color

    public static let system = Self(
        background: Color(nsColor: .windowBackgroundColor),
        surface: Color(nsColor: .controlBackgroundColor),
        surfaceElevated: Color(nsColor: .textBackgroundColor),
        textPrimary: Color(nsColor: .labelColor),
        textSecondary: Color(nsColor: .secondaryLabelColor),
        accent: Color(nsColor: .controlAccentColor),
        danger: Color(nsColor: .systemRed),
        success: Color(nsColor: .systemGreen),
        divider: Color(nsColor: .separatorColor),
        textOnAccent: Color(nsColor: .white)
    )
}
