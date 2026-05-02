public protocol AssociatedFilesScanning: Sendable {
    func scan(for metadata: AppMetadata) async throws -> [AssociatedFile]
}
