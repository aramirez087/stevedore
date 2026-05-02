import Foundation

public final class FakeAssociatedFilesScanner: AssociatedFilesScanning, @unchecked Sendable {
    public var files: [AssociatedFile]
    public var error: (any Error)?

    public init(files: [AssociatedFile] = [], error: (any Error)? = nil) {
        self.files = files
        self.error = error
    }

    public func scan(for metadata: AppMetadata) async throws -> [AssociatedFile] {
        if let error = self.error { throw error }
        return self.files
    }
}
