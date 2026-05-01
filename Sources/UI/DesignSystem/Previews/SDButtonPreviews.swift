import SwiftUI

#Preview("SDButton – Light") {
    VStack(spacing: Spacing.md) {
        SDButton("Primary Action", style: .primary, action: {})
        SDButton("Secondary Action", style: .secondary, action: {})
        SDButton("Delete", style: .destructive, action: {})
    }
    .padding(Spacing.md)
    .preferredColorScheme(.light)
}

#Preview("SDButton – Dark") {
    VStack(spacing: Spacing.md) {
        SDButton("Primary Action", style: .primary, action: {})
        SDButton("Secondary Action", style: .secondary, action: {})
        SDButton("Delete", style: .destructive, action: {})
    }
    .padding(Spacing.md)
    .preferredColorScheme(.dark)
}
