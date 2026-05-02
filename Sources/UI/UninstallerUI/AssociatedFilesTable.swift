import DesignSystem
import FeaturesUninstaller
import SwiftUI

public struct AssociatedFilesTable: View {
    @Bindable private var viewModel: UninstallerViewModel
    @State private var sortOrder: [KeyPathComparator<AssociatedFile>] = []

    @Environment(\.theme) private var theme

    private var homeDir: String {
        FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
    }

    public init(viewModel: UninstallerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            Table(self.viewModel.displayedFiles, sortOrder: self.$sortOrder) {
                TableColumn("") { row in
                    HStack(spacing: Spacing.xs) {
                        Toggle("", isOn: Binding(
                            get: { self.viewModel.selectedIDs.contains(row.id) },
                            set: { _ in self.viewModel.toggleSelection(row.id) }
                        ))
                        .toggleStyle(.checkbox)
                        .disabled(row.requiresAdmin)
                        if row.requiresAdmin {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(self.theme.colors.textSecondary)
                        }
                    }
                }
                .width(44)
                TableColumn("Path", value: \.url.lastPathComponent) { row in
                    Text(row.url.path(percentEncoded: false).replacingOccurrences(of: self.homeDir, with: "~"))
                        .font(self.theme.typography.body)
                        .foregroundStyle(row.requiresAdmin ? self.theme.colors.textSecondary : self.theme.colors
                            .textPrimary)
                        .lineLimit(1)
                }
                TableColumn("Size", value: \.sizeInBytes) { row in
                    Text(ByteCountFormatter.string(fromByteCount: row.sizeInBytes, countStyle: .file))
                        .font(self.theme.typography.body)
                        .foregroundStyle(self.theme.colors.textSecondary)
                }
                TableColumn("Modified", value: \.lastModified) { row in
                    Text(row.lastModified, style: .date)
                        .font(self.theme.typography.body)
                        .foregroundStyle(self.theme.colors.textSecondary)
                }
                TableColumn("Confidence", value: \.confidence) { row in
                    self.confidenceBadge(row.confidence)
                }
                TableColumn("Reason", value: \.reason) { row in
                    Text(row.reason)
                        .font(self.theme.typography.body)
                        .foregroundStyle(self.theme.colors.textSecondary)
                }
            }
            .onChange(of: self.sortOrder) { _, newOrder in
                self.applySort(newOrder)
            }
            if self.viewModel.lowConfidenceCount > 0 {
                Button(self.viewModel
                    .showLowConfidence ? "Hide low confidence" :
                    "Show all (\(self.viewModel.lowConfidenceCount) more)") {
                        self.viewModel.showLowConfidence.toggle()
                    }
                    .buttonStyle(.plain)
                    .font(self.theme.typography.caption)
                    .foregroundStyle(self.theme.colors.accent)
                    .padding(.vertical, Spacing.sm)
            }
        }
    }

    @ViewBuilder
    private func confidenceBadge(_ confidence: Confidence) -> some View {
        let (label, color): (String, Color) = switch confidence {
        case .high: ("High", self.theme.colors.success)
        case .medium: ("Medium", self.theme.colors.accent)
        case .low: ("Low", self.theme.colors.textSecondary)
        }
        Text(label)
            .font(self.theme.typography.caption)
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func applySort(_ order: [KeyPathComparator<AssociatedFile>]) {
        guard let first = order.first else { return }
        let ascending = first.order == .forward
        switch first.keyPath {
        case \AssociatedFile.url.lastPathComponent:
            self.viewModel.sortKey = .path
        case \AssociatedFile.sizeInBytes:
            self.viewModel.sortKey = .size
        case \AssociatedFile.lastModified:
            self.viewModel.sortKey = .modified
        case \AssociatedFile.confidence:
            self.viewModel.sortKey = .confidence
        default:
            break
        }
        self.viewModel.sortAscending = ascending
    }
}
