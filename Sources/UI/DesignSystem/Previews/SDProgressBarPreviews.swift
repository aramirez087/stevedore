import SwiftUI

#Preview("SDProgressBar – Light") {
    VStack(spacing: Spacing.md) {
        SDProgressBar(value: 0)
        SDProgressBar(value: 0.35)
        SDProgressBar(value: 0.75)
        SDProgressBar(value: 1)
    }
    .frame(width: 240)
    .padding(Spacing.md)
    .preferredColorScheme(.light)
}

#Preview("SDProgressBar – Dark") {
    VStack(spacing: Spacing.md) {
        SDProgressBar(value: 0.2)
        SDProgressBar(value: 0.6)
    }
    .frame(width: 240)
    .padding(Spacing.md)
    .preferredColorScheme(.dark)
}
