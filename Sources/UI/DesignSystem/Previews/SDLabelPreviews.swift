import SwiftUI

#Preview("SDLabel – Light") {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        SDLabel("Primary label text", variant: .primary)
        SDLabel("Secondary label text", variant: .secondary)
        SDLabel("Caption label text", variant: .caption)
        SDLabel("/usr/local/bin/swift", variant: .mono)
    }
    .padding(Spacing.md)
    .preferredColorScheme(.light)
}

#Preview("SDLabel – Dark") {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        SDLabel("Primary label text", variant: .primary)
        SDLabel("Secondary label text", variant: .secondary)
        SDLabel("Caption label text", variant: .caption)
        SDLabel("/usr/local/bin/swift", variant: .mono)
    }
    .padding(Spacing.md)
    .preferredColorScheme(.dark)
}
