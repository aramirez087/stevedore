import Core
import SwiftUI

#Preview("FileKindIcon – Light") {
    HStack(spacing: Spacing.lg) {
        VStack(spacing: Spacing.sm) {
            FileKindIcon(kind: .directory, size: .sm)
            FileKindIcon(kind: .directory, size: .md)
            FileKindIcon(kind: .directory, size: .lg)
        }
        VStack(spacing: Spacing.sm) {
            FileKindIcon(kind: .regularFile, fileExtension: "pdf", size: .sm)
            FileKindIcon(kind: .regularFile, fileExtension: "pdf", size: .md)
            FileKindIcon(kind: .regularFile, fileExtension: "pdf", size: .lg)
        }
        VStack(spacing: Spacing.sm) {
            FileKindIcon(kind: .regularFile, fileExtension: "jpg", size: .sm)
            FileKindIcon(kind: .regularFile, fileExtension: "jpg", size: .md)
            FileKindIcon(kind: .regularFile, fileExtension: "jpg", size: .lg)
        }
        VStack(spacing: Spacing.sm) {
            FileKindIcon(kind: .symbolicLink, size: .sm)
            FileKindIcon(kind: .symbolicLink, size: .md)
            FileKindIcon(kind: .symbolicLink, size: .lg)
        }
    }
    .padding(Spacing.md)
    .preferredColorScheme(.light)
}

#Preview("FileKindIcon – Dark") {
    HStack(spacing: Spacing.lg) {
        VStack(spacing: Spacing.sm) {
            FileKindIcon(kind: .directory, size: .sm)
            FileKindIcon(kind: .directory, size: .md)
            FileKindIcon(kind: .directory, size: .lg)
        }
        VStack(spacing: Spacing.sm) {
            FileKindIcon(kind: .regularFile, fileExtension: "swift", size: .sm)
            FileKindIcon(kind: .regularFile, fileExtension: "swift", size: .md)
            FileKindIcon(kind: .regularFile, fileExtension: "swift", size: .lg)
        }
        VStack(spacing: Spacing.sm) {
            FileKindIcon(kind: .unknown, size: .sm)
            FileKindIcon(kind: .unknown, size: .md)
            FileKindIcon(kind: .unknown, size: .lg)
        }
    }
    .padding(Spacing.md)
    .preferredColorScheme(.dark)
}
