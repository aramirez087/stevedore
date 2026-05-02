import Core
import FeaturesUninstaller
import Foundation
import Observation
import SwiftUI

// MARK: - ScanState

/// Lifecycle of the scanner within the view-model.
public enum ScanState: Sendable, Equatable {
    case idle
    case scanning
    case ready
    case error(String)
}

// MARK: - FileRow

/// View-model row wrapping an `AssociatedFile` with a mutable selection flag.
@MainActor
@Observable
public final class FileRow: Identifiable {
    public let id: UUID
    public let file: AssociatedFile
    /// Whether this file is included in the pending uninstall plan.
    public var isSelected: Bool

    public init(file: AssociatedFile, selected: Bool) {
        self.id = file.id
        self.file = file
        self.isSelected = selected
    }
}

// MARK: - UninstallerViewModel

/// `@MainActor`-isolated `@Observable` view-model that drives `UninstallerSheet`.
///
/// Lifecycle:
/// 1. Create with `init()`.
/// 2. Call `load(appURL:)` to start scanning (also triggered by drop).
/// 3. The view reflects `scanState`, `metadata`, and `rows`.
/// 4. Call `confirm()` to execute the current selection.
@MainActor
@Observable
public final class UninstallerViewModel {
    // MARK: - Public state

    public var scanState: ScanState = .idle
    public var metadata: AppMetadata?
    public var rows: [FileRow] = []
    /// Error set when a drop or load fails validation, cleared on next load attempt.
    public private(set) var dropError: String?

    // MARK: - Callbacks

    public var onDismiss: (() -> Void)?
    public var onCompleted: ((UninstallSummary) -> Void)?

    // MARK: - Private

    private let reader: AppMetadataReader
    private let scanner: AssociatedFilesScanner
    private let executor: UninstallExecutor

    // MARK: - Init

    public init(
        reader: AppMetadataReader = AppMetadataReader(),
        scanner: AssociatedFilesScanner = AssociatedFilesScanner(),
        executor: UninstallExecutor = UninstallExecutor()
    ) {
        self.reader = reader
        self.scanner = scanner
        self.executor = executor
    }

    // MARK: - Public API

    /// Load metadata and scan for associated files for the app at `appURL`.
    ///
    /// Validates the bundle before scanning — sets `dropError` and returns
    /// without entering scan flow for non-bundle paths.
    public func load(appURL: URL) async {
        self.dropError = nil
        self.scanState = .scanning
        self.metadata = nil
        self.rows = []

        // Validate bundle synchronously (cheap FS check).
        let parsedMetadata: AppMetadata
        do {
            parsedMetadata = try self.reader.read(from: appURL)
        } catch {
            let message = (error as? AppMetadataReaderError)?.errorDescription
                ?? error.localizedDescription
            self.dropError = message
            self.scanState = .idle
            return
        }

        self.metadata = parsedMetadata

        // Run the scanner off the main actor to avoid blocking UI.
        let capturedScanner = self.scanner
        let files = await Task.detached(priority: .userInitiated) {
            capturedScanner.scan(for: parsedMetadata)
        }.value

        self.rows = self.makeRows(from: files)
        self.scanState = .ready
    }

    /// Dismiss without executing.
    public func cancel() {
        self.onDismiss?()
    }

    /// Move the app + all selected associated files to Trash.
    public func confirm() async {
        guard let meta = metadata else { return }

        let selected = self.rows.filter(\.isSelected).map(\.file)
        let plan = UninstallPlan(metadata: meta, selectedFiles: selected)

        let capturedExecutor = self.executor
        let summary = await Task.detached(priority: .userInitiated) {
            capturedExecutor.execute(plan)
        }.value

        self.onCompleted?(summary)
        self.onDismiss?()
    }

    // MARK: - Computed helpers

    /// Count of items that will move to Trash (app + selected associated files).
    public var confirmationItemCount: Int {
        1 + self.selectedRows.count
    }

    /// Aggregate byte size of selected associated files.
    public var selectedAssociatedBytes: Int64 {
        self.selectedRows.reduce(0) { $0 + $1.file.sizeInBytes }
    }

    /// Whether the confirm button should be enabled.
    public var canConfirm: Bool {
        self.scanState == .ready && self.metadata != nil
    }

    // MARK: - Private helpers

    private var selectedRows: [FileRow] {
        self.rows.filter(\.isSelected)
    }

    private func makeRows(from files: [AssociatedFile]) -> [FileRow] {
        files.map { file in
            // Default selection: high-confidence only; system paths never selected.
            let selected = file.confidence == .high && !file.requiresAdmin
            return FileRow(file: file, selected: selected)
        }
    }
}
