import Foundation

public protocol AppMetadataReading: Sendable {
    func readMetadata(from bundleURL: URL) throws -> AppMetadata
}
