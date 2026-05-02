import Core
import DesignSystem
import SwiftUI

// Both types are at file scope — SwiftLint's `nesting` rule rejects types
// nested more than one level deep under `--strict`.

struct PathSegmentData {
    let path: FilePath
    let label: String
    let isLast: Bool
}

enum BreadcrumbItem: Identifiable {
    case segment(id: Int, data: PathSegmentData)
    case ellipsis(id: Int, hidden: [FilePath])

    var id: Int {
        switch self {
        case .segment(let id, _): id
        case .ellipsis(let id, _): id
        }
    }
}

/// One breadcrumb segment: a tappable label and an optional chevron that opens
/// a subfolder picker popover. `subfolderProvider` is called lazily on popover open.
public struct PathBarSegment: View {
    public let path: FilePath
    public let label: String
    public let isLast: Bool
    public var onTap: (FilePath) -> Void
    public var subfolderProvider: @MainActor (FilePath) async -> [FilePath]

    @State private var isShowingPicker = false
    @State private var subfolders: [FilePath] = []
    @State private var isLoading = false

    @Environment(\.theme) private var theme

    public init(
        path: FilePath,
        label: String,
        isLast: Bool,
        onTap: @escaping (FilePath) -> Void,
        subfolderProvider: @escaping @MainActor (FilePath) async -> [FilePath] = { _ in [] }
    ) {
        self.path = path
        self.label = label
        self.isLast = isLast
        self.onTap = onTap
        self.subfolderProvider = subfolderProvider
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            Button(self.label) { self.onTap(self.path) }
                .buttonStyle(.plain)
                .font(self.theme.typography.body)
                .foregroundStyle(self.isLast ? self.theme.colors.textPrimary : self.theme.colors.textSecondary)

            if !self.isLast {
                Button {
                    self.isShowingPicker = true
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(self.theme.colors.textSecondary)
                        .imageScale(.small)
                }
                .buttonStyle(.plain)
                .popover(isPresented: self.$isShowingPicker) {
                    self.subfolderPickerContent
                }
                .task(id: self.isShowingPicker) {
                    guard self.isShowingPicker else { return }
                    self.isLoading = true
                    self.subfolders = await self.subfolderProvider(self.path)
                    self.isLoading = false
                }
            }
        }
    }

    private var subfolderPickerContent: some View {
        Group {
            if self.isLoading {
                ProgressView()
                    .padding(Spacing.md)
            } else if self.subfolders.isEmpty {
                Text("No subfolders")
                    .font(self.theme.typography.caption)
                    .foregroundStyle(self.theme.colors.textSecondary)
                    .padding(Spacing.md)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(self.subfolders, id: \.self) { sub in
                        Button(sub.displayName) {
                            self.isShowingPicker = false
                            self.onTap(sub)
                        }
                        .buttonStyle(.plain)
                        .font(self.theme.typography.body)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
        }
        .frame(minWidth: 160)
    }
}
