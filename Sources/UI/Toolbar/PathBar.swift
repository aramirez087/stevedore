import Core
import DesignSystem
import SwiftUI

/// Breadcrumb path bar for a single file pane.
///
/// Derives `BreadcrumbItem` segments from the current `FilePath`. When the
/// path has more than `maxVisible` prefixes the middle segments are collapsed
/// into an ellipsis `Menu`. `breadcrumbs` is `internal` for testability.
public struct PathBar: View {
    public let path: FilePath
    public var onNavigate: (FilePath) -> Void
    public var subfolderProvider: @MainActor (FilePath) async -> [FilePath]

    /// Maximum number of visible breadcrumb segments before collapsing middle ones.
    static let maxVisible: Int = 5

    @Environment(\.theme) private var theme

    public init(
        path: FilePath,
        onNavigate: @escaping (FilePath) -> Void,
        subfolderProvider: @escaping @MainActor (FilePath) async -> [FilePath] = { _ in [] }
    ) {
        self.path = path
        self.onNavigate = onNavigate
        self.subfolderProvider = subfolderProvider
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(self.breadcrumbs) { item in
                    switch item {
                    case .segment(_, let data):
                        PathBarSegment(
                            path: data.path,
                            label: data.label,
                            isLast: data.isLast,
                            onTap: self.onNavigate,
                            subfolderProvider: self.subfolderProvider
                        )
                    case .ellipsis(_, let hidden):
                        self.ellipsisButton(hidden: hidden)
                    }
                }
            }
            .padding(.horizontal, Spacing.sm)
        }
        .frame(height: 28)
        .background(self.theme.colors.surface)
    }

    /// Internal so @testable import UIToolbar can exercise breadcrumb derivation.
    var breadcrumbs: [BreadcrumbItem] {
        let root = FilePath.root(self.path.scheme)
        var prefixes: [(path: FilePath, label: String)] = [(root, root.displayName)]
        for i in 0 ..< self.path.components.count {
            let sub = FilePath(scheme: path.scheme, components: Array(self.path.components.prefix(i + 1)))
            prefixes.append((sub, self.path.components[i]))
        }

        guard prefixes.count > Self.maxVisible else {
            return prefixes.enumerated().map { idx, pair in
                .segment(
                    id: idx,
                    data: PathSegmentData(path: pair.path, label: pair.label, isLast: idx == prefixes.count - 1)
                )
            }
        }

        // Overflow: keep root + ellipsis + last (maxVisible - 2) segments.
        let tailCount = Self.maxVisible - 2
        let head = prefixes[0]
        let tail = Array(prefixes.suffix(tailCount))
        let hidden = Array(prefixes[1 ..< (prefixes.count - tailCount)])

        var items: [BreadcrumbItem] = []
        items.append(.segment(id: 0, data: PathSegmentData(path: head.path, label: head.label, isLast: false)))
        items.append(.ellipsis(id: 1, hidden: hidden.map(\.path)))
        for (i, pair) in tail.enumerated() {
            let isLast = i == tail.count - 1
            items.append(.segment(id: i + 2, data: PathSegmentData(path: pair.path, label: pair.label, isLast: isLast)))
        }
        return items
    }

    private func ellipsisButton(hidden: [FilePath]) -> some View {
        Menu {
            ForEach(hidden, id: \.self) { p in
                Button(p.displayName) { self.onNavigate(p) }
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text("…")
                    .foregroundStyle(self.theme.colors.textSecondary)
                    .font(self.theme.typography.body)
                Image(systemName: "chevron.right")
                    .foregroundStyle(self.theme.colors.textSecondary)
                    .imageScale(.small)
            }
        }
        .buttonStyle(.plain)
    }
}
