import Core
@testable import FileSystemRemote
import Foundation
import os

/// In-memory WebDAV transport for testing.
///
/// Records all requests so tests can assert on what was sent.
public final class FakeWebDAVTransport: WebDAVTransport, @unchecked Sendable {
    public struct Call: Sendable {
        public let method: String
        public let path: String
        public let headers: [String: String]
        public let body: Data?
    }

    private struct State {
        var calls: [Call] = []
        var files: [String: Data] = [:]
        var collections: Set<String> = ["/"]
        var statusOverride: Int?
    }

    private let lock: OSAllocatedUnfairLock<State>

    public init(files: [String: Data] = [:], collections: [String] = []) {
        var s = State()
        s.files = files
        s.collections = Set(collections).union(["/"])
        self.lock = OSAllocatedUnfairLock(initialState: s)
    }

    public func setStatusOverride(_ code: Int?) {
        self.lock.withLock { $0.statusOverride = code }
    }

    public func request(
        method: String,
        path: String,
        headers: [String: String],
        body: Data?
    ) async throws -> WebDAVResponse {
        self.lock.withLock { $0.calls.append(Call(method: method, path: path, headers: headers, body: body)) }

        let override = self.lock.withLock { $0.statusOverride }
        if let code = override {
            return WebDAVResponse(statusCode: code, headers: [:], body: nil)
        }

        return self.dispatch(method: method, path: path, headers: headers, body: body)
    }

    // MARK: - Inspection

    public var calls: [Call] {
        self.lock.withLock { $0.calls }
    }

    // MARK: - Private dispatch

    private func dispatch(method: String, path: String, headers: [String: String], body: Data?) -> WebDAVResponse {
        switch method {
        case "PROPFIND": self.handlePropfind(path: path, headers: headers)
        case "MKCOL": self.handleMkcol(path: path)
        case "DELETE": self.handleDelete(path: path)
        case "MOVE": self.handleMove(path: path, headers: headers)
        case "COPY": self.handleCopy(path: path, headers: headers)
        case "PUT": self.handlePut(path: path, body: body)
        case "GET": self.handleGet(path: path)
        default: WebDAVResponse(statusCode: 405, headers: [:], body: nil)
        }
    }

    private func handlePropfind(path: String, headers: [String: String]) -> WebDAVResponse {
        let depth = headers["Depth"] ?? "0"
        return self.lock.withLock { state in
            self.propfindResponse(state: state, path: path, depth: depth)
        }
    }

    private func handleMkcol(path: String) -> WebDAVResponse {
        self.lock.withLock { $0.collections.insert(path) }
        return WebDAVResponse(statusCode: 201, headers: [:], body: nil)
    }

    private func handleDelete(path: String) -> WebDAVResponse {
        self.lock.withLock { state in
            state.files[path] = nil
            state.collections.remove(path)
        }
        return WebDAVResponse(statusCode: 204, headers: [:], body: nil)
    }

    private func handleMove(path: String, headers: [String: String]) -> WebDAVResponse {
        guard let dest = headers["Destination"] else {
            return WebDAVResponse(statusCode: 400, headers: [:], body: nil)
        }
        self.lock.withLock { state in
            if let data = state.files.removeValue(forKey: path) {
                state.files[dest] = data
            } else if state.collections.remove(path) != nil {
                state.collections.insert(dest)
            }
        }
        return WebDAVResponse(statusCode: 201, headers: [:], body: nil)
    }

    private func handleCopy(path: String, headers: [String: String]) -> WebDAVResponse {
        guard let dest = headers["Destination"] else {
            return WebDAVResponse(statusCode: 400, headers: [:], body: nil)
        }
        self.lock.withLock { state in
            state.files[dest] = state.files[path]
        }
        return WebDAVResponse(statusCode: 201, headers: [:], body: nil)
    }

    private func handlePut(path: String, body: Data?) -> WebDAVResponse {
        self.lock.withLock { $0.files[path] = body }
        return WebDAVResponse(statusCode: 201, headers: [:], body: nil)
    }

    private func handleGet(path: String) -> WebDAVResponse {
        let data = self.lock.withLock { $0.files[path] }
        if let d = data { return WebDAVResponse(statusCode: 200, headers: [:], body: d) }
        return WebDAVResponse(statusCode: 404, headers: [:], body: nil)
    }

    // MARK: - PROPFIND XML generation

    private func propfindResponse(state: State, path: String, depth: String) -> WebDAVResponse {
        var responses = [
            propfindEntry(
                href: path,
                isCollection: state.collections.contains(path),
                size: nil
            ),
        ]

        if depth == "1" {
            for (fp, data) in state.files {
                let parent = (fp as NSString).deletingLastPathComponent
                guard (parent.isEmpty ? "/" : parent) == path else { continue }
                responses.append(self.propfindEntry(href: fp, isCollection: false, size: data.count))
            }
            for col in state.collections where col != path {
                let parent = (col as NSString).deletingLastPathComponent
                guard (parent.isEmpty ? "/" : parent) == path else { continue }
                responses.append(propfindEntry(href: col, isCollection: true, size: nil))
            }
        }

        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <D:multistatus xmlns:D="DAV:">
        \(responses.joined(separator: "\n"))
        </D:multistatus>
        """
        return WebDAVResponse(statusCode: 207, headers: [:], body: Data(xml.utf8))
    }

    private func propfindEntry(href: String, isCollection: Bool, size: Int?) -> String {
        let resourceType = isCollection ? "<D:collection/>" : ""
        let sizeXML = size.map { "<D:getcontentlength>\($0)</D:getcontentlength>" } ?? ""
        return """
        <D:response>
          <D:href>\(href)</D:href>
          <D:propstat>
            <D:prop>
              <D:resourcetype>\(resourceType)</D:resourcetype>
              \(sizeXML)
            </D:prop>
            <D:status>HTTP/1.1 200 OK</D:status>
          </D:propstat>
        </D:response>
        """
    }
}
