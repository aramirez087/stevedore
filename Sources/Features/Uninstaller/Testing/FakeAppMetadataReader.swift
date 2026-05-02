import Foundation

public final class FakeAppMetadataReader: AppMetadataReading, @unchecked Sendable {
    public var result: Result<AppMetadata, any Error>

    public init(result: Result<AppMetadata, any Error>) {
        self.result = result
    }

    public func readMetadata(from bundleURL: URL) throws -> AppMetadata {
        try self.result.get()
    }
}
