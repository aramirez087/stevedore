import Foundation

/// A raw HTTP response from a WebDAV server.
public struct WebDAVResponse: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data?

    public init(statusCode: Int, headers: [String: String], body: Data?) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

/// Transport abstraction for WebDAV. URLSession-backed implementation is in
/// `URLSessionWebDAVTransport`; fakes implement this protocol directly.
public protocol WebDAVTransport: Sendable {
    func request(
        method: String,
        path: String,
        headers: [String: String],
        body: Data?
    ) async throws -> WebDAVResponse
}
