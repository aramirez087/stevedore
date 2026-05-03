import Foundation

/// Transport abstraction for FTP. URLSession-backed implementation is in
/// `URLSessionFTPTransport`; fakes implement this protocol directly.
public protocol FTPTransport: Sendable {
    func connect() async throws
    /// Raw LIST response bytes. Caller decodes with `FTPListParser`.
    func list(at path: String) async throws -> Data
    /// Raw MLSD response bytes. Throws if the server does not support MLSD.
    func mlsd(at path: String) async throws -> Data
    func retrieve(at path: String) -> AsyncThrowingStream<Data, any Error>
    func store(at path: String, data: AsyncThrowingStream<Data, any Error>) async throws
    func makeDirectory(at path: String) async throws
    func rename(from: String, to: String) async throws
    func delete(at path: String) async throws
    func disconnect() async
}
