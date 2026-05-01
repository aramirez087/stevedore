import SwiftUI

public struct Typography: Sendable {
    public let largeTitle: Font
    public let title: Font
    public let body: Font
    public let caption: Font
    public let mono: Font

    public static let system = Self(
        largeTitle: .system(size: 26, weight: .bold),
        title: .system(size: 20, weight: .semibold),
        body: .system(size: 13, weight: .regular),
        caption: .system(size: 11, weight: .regular),
        mono: .system(size: 13, weight: .regular, design: .monospaced)
    )
}
