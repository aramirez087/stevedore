import Core

/// Summary of a completed archive extraction.
public struct ArchiveExtractionResult: Hashable, Sendable {
    public let entriesExtracted: Int
    public let bytesProcessed: Int64

    public init(entriesExtracted: Int, bytesProcessed: Int64) {
        self.entriesExtracted = entriesExtracted
        self.bytesProcessed = bytesProcessed
    }
}
