import SwiftUI

#Preview("SDListRow – Light") {
    VStack(spacing: 0) {
        SDListRow(content: .singleLine(title: "Documents"), symbolName: "folder", isSelected: false)
        SDListRow(content: .singleLine(title: "Downloads"), symbolName: "arrow.down.circle", isSelected: true)
        SDListRow(
            content: .doubleLine(title: "Report.pdf", subtitle: "Modified today, 2.4 MB"),
            symbolName: "doc.richtext",
            isSelected: false
        )
        SDListRow(
            content: .doubleLine(title: "Archive.zip", subtitle: "Modified yesterday, 18 MB"),
            symbolName: "archivebox",
            isSelected: true
        )
    }
    .frame(width: 300)
    .padding(.vertical, Spacing.xs)
    .preferredColorScheme(.light)
}

#Preview("SDListRow – Dark") {
    VStack(spacing: 0) {
        SDListRow(content: .singleLine(title: "Documents"), symbolName: "folder", isSelected: false)
        SDListRow(content: .singleLine(title: "Downloads"), symbolName: "arrow.down.circle", isSelected: true)
        SDListRow(
            content: .doubleLine(title: "Report.pdf", subtitle: "Modified today, 2.4 MB"),
            symbolName: "doc.richtext",
            isSelected: false
        )
    }
    .frame(width: 300)
    .padding(.vertical, Spacing.xs)
    .preferredColorScheme(.dark)
}
