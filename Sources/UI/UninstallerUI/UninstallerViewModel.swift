import FeaturesUninstaller
import Foundation
import SwiftUI

@MainActor
@Observable
public final class UninstallerViewModel {
    public private(set) var appMetadata: AppMetadata?
    public private(set) var scanState: ScanState = .idle
    public var selectedIDs: Set<UUID> = []
    public var showLowConfidence: Bool = false
    public var sortKey: AssociatedFileSortKey = .confidence
    public var sortAscending: Bool = false
    public private(set) var dropError: String?
    public private(set) var isExecuting: Bool = false

    @ObservationIgnored private let metadataReader: any AppMetadataReading
    @ObservationIgnored private let scanner: any AssociatedFilesScanning
    @ObservationIgnored private let executor: any UninstallExecuting

    public init(
        metadataReader: some AppMetadataReading = AppMetadataReader(),
        scanner: some AssociatedFilesScanning = AssociatedFilesScanner(),
        executor: some UninstallExecuting = UninstallExecutor()
    ) {
        self.metadataReader = metadataReader
        self.scanner = scanner
        self.executor = executor
    }

    public var allFiles: [AssociatedFile] {
        if case .ready(let files) = self.scanState { return files }
        return []
    }

    public var displayedFiles: [AssociatedFile] {
        let files = self.showLowConfidence
            ? self.allFiles
            : self.allFiles.filter { $0.confidence > .low }
        return files.sorted { lhs, rhs in
            let ascending = self.sortAscending
            switch self.sortKey {
            case .path:
                let result = lhs.url.lastPathComponent.localizedCompare(rhs.url.lastPathComponent)
                return ascending ? result == .orderedAscending : result == .orderedDescending
            case .size:
                return ascending ? lhs.sizeInBytes < rhs.sizeInBytes : lhs.sizeInBytes > rhs.sizeInBytes
            case .modified:
                return ascending ? lhs.lastModified < rhs.lastModified : lhs.lastModified > rhs.lastModified
            case .confidence:
                return ascending ? lhs.confidence < rhs.confidence : lhs.confidence > rhs.confidence
            }
        }
    }

    public var lowConfidenceCount: Int {
        self.allFiles.count(where: { $0.confidence == .low })
    }

    public var selectedFiles: [AssociatedFile] {
        self.allFiles.filter { self.selectedIDs.contains($0.id) }
    }

    public var selectedItemCount: Int {
        1 + self.selectedFiles.count
    }

    public var totalSelectedBytes: Int64 {
        let base = self.appMetadata?.bundleSizeInBytes ?? 0
        return base + self.selectedFiles.reduce(0) { $0 + $1.sizeInBytes }
    }

    public var confirmationText: String {
        let sizeStr = ByteCountFormatter.string(fromByteCount: self.totalSelectedBytes, countStyle: .file)
        return "Move \(self.selectedItemCount) item\(self.selectedItemCount == 1 ? "" : "s") (\(sizeStr)) to Trash"
    }

    /// Validates the bundle and performs the scan. Callers that want non-blocking
    /// behaviour should wrap this in Task { await vm.load(appURL:) }.
    public func load(appURL: URL) async {
        self.dropError = nil
        guard appURL.pathExtension == "app" else {
            self.dropError = "'\(appURL.lastPathComponent)' is not an app bundle."
            return
        }
        let plistPath = appURL.appending(path: "Contents/Info.plist", directoryHint: .notDirectory)
            .path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: plistPath) else {
            self.dropError = "'\(appURL.lastPathComponent)' is missing Contents/Info.plist."
            return
        }
        self.scanState = .scanning
        do {
            let metadata = try self.metadataReader.readMetadata(from: appURL)
            self.appMetadata = metadata
            let files = try await self.scanner.scan(for: metadata)
            self.scanState = .ready(files)
            self.applyDefaultSelections(files: files)
        } catch {
            self.scanState = .failed(error.localizedDescription)
        }
    }

    public func toggleSelection(_ id: UUID) {
        guard let file = self.allFiles.first(where: { $0.id == id }), !file.requiresAdmin else { return }
        if self.selectedIDs.contains(id) {
            self.selectedIDs.remove(id)
        } else {
            self.selectedIDs.insert(id)
        }
    }

    public func confirmUninstall() async {
        guard !self.isExecuting, let metadata = self.appMetadata else { return }
        self.isExecuting = true
        let plan = UninstallPlan(appMetadata: metadata, selectedFiles: self.selectedFiles)
        try? await self.executor.execute(plan: plan)
        self.isExecuting = false
    }

    public func cancel() {
        self.scanState = .idle
        self.appMetadata = nil
        self.selectedIDs = []
        self.dropError = nil
    }

    private func applyDefaultSelections(files: [AssociatedFile]) {
        self.selectedIDs = Set(files.filter { $0.confidence == .high && !$0.requiresAdmin }.map(\.id))
    }
}
