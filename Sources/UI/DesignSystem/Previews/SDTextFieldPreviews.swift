import SwiftUI

#Preview("SDTextField – Light") {
    @Previewable @State var text = "Sample text"
    SDTextField("Placeholder", text: $text)
        .frame(width: 240)
        .padding(Spacing.md)
        .preferredColorScheme(.light)
}

#Preview("SDTextField – Dark") {
    @Previewable @State var text = ""
    SDTextField("Enter value…", text: $text)
        .frame(width: 240)
        .padding(Spacing.md)
        .preferredColorScheme(.dark)
}
