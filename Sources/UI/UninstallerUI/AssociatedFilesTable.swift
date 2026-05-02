import Core
import FeaturesUninstaller
import Foundation
import SwiftUI

// MARK: - SortColumn

/// The column currently used to sort the associated-files table.
public enum SortColumn: String, Sendable, CaseIterable, Hashable {
    case path
    case size
    case modified
    case confidence
}

// MARK: - AssociatedFilesTable

/// Sortable table listing `FileRow` entries with a checkbox, path, size,
/// last-modified date, confidence score, and match reason.
///
/// System-owned paths (`.requiresAdmin == true`) are shown with a lock icon
/// and the checkbox is disabled — the user cannot select them.
public struct AssociatedFilesTable: View {
    @Binding var rows: [FileRow]
    @State private var sortColumn: SortColumn = .confidence
    @State private var sortAscending: Bool = false
    @State private var showLow: Bool = false

    public init(rows: Binding<[FileRow]>) {
        self._rows = rows
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            self.columnHeaders
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(self.visibleRows) { row in
                        self.rowView(row)
                        Divider()
                    }
                }
            }
            if self.hasLowConfidenceRows {
                self.showLowButton
                    .padding(.horizontal)
                    .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Column headers

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            // Checkbox column
            Color.clear.frame(width: 32, height: 1)

            self.headerButton("Path", column: .path)
                .frame(maxWidth: .infinity, alignment: .leading)
            self.headerButton("Size", column: .size)
                .frame(width: 80, alignment: .trailing)
            self.headerButton("Modified", column: .modified)
                .frame(width: 120, alignment: .leading)
            self.headerButton("Confidence", column: .confidence)
                .frame(width: 100, alignment: .leading)
            Text("Reason")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 160, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func headerButton(_ title: String, column: SortColumn) -> some View {
        Button {
            if self.sortColumn == column {
                self.sortAscending.toggle()
            } else {
                self.sortColumn = column
                self.sortAscending = column != .confidence
            }
            self.applySort()
        } label: {
            HStack(spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                if self.sortColumn == column {
                    Image(systemName: self.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Row view

    private func rowView(_ row: FileRow) -> some View {
        HStack(spacing: 0) {
            self.checkboxCell(row)
                .frame(width: 32, alignment: .center)
            self.pathCell(row)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(ByteCountFormatter.string(fromByteCount: row.file.sizeInBytes, countStyle: .file))
                .font(.body.monospacedDigit())
                .foregroundStyle(row.file.requiresAdmin ? .secondary : .primary)
                .frame(width: 80, alignment: .trailing)
            Text(row.file.modificationDate.map { Self.dateFormatter.string(from: $0) } ?? "—")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            self.confidenceCell(row)
                .frame(width: 100, alignment: .leading)
            Text(row.file.reason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(width: 160, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Cells

    @ViewBuilder
    private func checkboxCell(_ row: FileRow) -> some View {
        if row.file.requiresAdmin {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
                .font(.caption)
                .accessibilityLabel("System-owned — cannot be removed")
        } else {
            Toggle(isOn: Binding(
                get: { row.isSelected },
                set: { row.isSelected = $0 }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .accessibilityLabel("Include \(row.file.url.lastPathComponent) in removal")
        }
    }

    private func pathCell(_ row: FileRow) -> some View {
        HStack(spacing: 4) {
            if row.file.requiresAdmin {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            Text(Self.redactHome(row.file.url.path))
                .font(.body.monospaced())
                .foregroundStyle(row.file.requiresAdmin ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func confidenceCell(_ row: FileRow) -> some View {
        let color: Color = switch row.file.confidence {
        case .high: .green
        case .medium: .orange
        case .low: .red
        }
        return Text(row.file.confidence.label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
    }

    // MARK: - "Show all" button for low-confidence items

    private var hasLowConfidenceRows: Bool {
        self.rows.contains { $0.file.confidence == .low }
    }

    private var showLowButton: some View {
        let label = self.showLow
            ? "Hide low-confidence items"
            : "Show all (\(self.lowCount) low-confidence \(self.lowCount == 1 ? "item" : "items"))"
        return Button(label) {
            self.showLow.toggle()
        }
        .font(.caption)
    }

    private var lowCount: Int {
        self.rows.count(where: { $0.file.confidence == .low })
    }

    // MARK: - Visibility filter

    private var visibleRows: [FileRow] {
        if self.showLow {
            return self.rows
        }
        return self.rows.filter { $0.file.confidence != .low }
    }

    // MARK: - Sort

    private func applySort() {
        self.rows.sort { a, b in
            let ascending = self.sortAscending
            switch self.sortColumn {
            case .path:
                return ascending
                    ? a.file.url.path < b.file.url.path
                    : a.file.url.path > b.file.url.path
            case .size:
                return ascending
                    ? a.file.sizeInBytes < b.file.sizeInBytes
                    : a.file.sizeInBytes > b.file.sizeInBytes
            case .modified:
                let aDate = a.file.modificationDate ?? .distantPast
                let bDate = b.file.modificationDate ?? .distantPast
                return ascending ? aDate < bDate : aDate > bDate
            case .confidence:
                return ascending
                    ? a.file.confidence < b.file.confidence
                    : a.file.confidence > b.file.confidence
            }
        }
    }

    // MARK: - Helpers

    /// Replace the home-directory prefix with `~` for display.
    public nonisolated static func redactHome(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt
    }()
}
