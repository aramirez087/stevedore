import SwiftUI

#Preview("SDSearchField – Light") {
    @Previewable @State var query = "Documents"
    SDSearchField(text: $query)
        .frame(width: 240)
        .padding(Spacing.md)
        .preferredColorScheme(.light)
}

#Preview("SDSearchField – Dark") {
    @Previewable @State var query = ""
    SDSearchField(text: $query)
        .frame(width: 240)
        .padding(Spacing.md)
        .preferredColorScheme(.dark)
}
