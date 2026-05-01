import Core
import SwiftUI

public struct FileKindIcon: View {
    private let kind: FileKind
    private let fileExtension: String?
    private let size: IconSize

    @Environment(\.theme) private var theme

    public init(kind: FileKind, fileExtension: String? = nil, size: IconSize = .md) {
        self.kind = kind
        self.fileExtension = fileExtension
        self.size = size
    }

    private var resolvedSymbolName: String {
        if self.kind == .regularFile, let ext = self.fileExtension {
            let candidate = IconRegistry.symbolName(forExtension: ext)
            return candidate == "doc" ? IconRegistry.symbolName(for: self.kind) : candidate
        }
        return IconRegistry.symbolName(for: self.kind)
    }

    public var body: some View {
        Image(systemName: self.resolvedSymbolName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: self.size.points, height: self.size.points)
            .foregroundStyle(self.theme.colors.textSecondary)
    }
}
