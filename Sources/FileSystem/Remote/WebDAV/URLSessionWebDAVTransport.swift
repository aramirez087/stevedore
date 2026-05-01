import Core
import Foundation

/// URLSession-backed WebDAV transport.
public final class URLSessionWebDAVTransport: WebDAVTransport, Sendable {
    private let baseURL: URL
    private let auth: RemoteAuthStrategy
    private let urlSession: URLSession

    public init(baseURL: URL, auth: RemoteAuthStrategy) {
        self.baseURL = baseURL
        self.auth = auth
        self.urlSession = URLSession(configuration: .default)
    }

    public func request(
        method: String,
        path: String,
        headers: [String: String],
        body: Data?
    ) async throws -> WebDAVResponse {
        let url = URL(string: path, relativeTo: baseURL)?.absoluteURL ?? self.baseURL
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body

        for (key, value) in headers {
            req.setValue(value, forHTTPHeaderField: key)
        }
        self.applyAuth(to: &req)

        let (data, response) = try await urlSession.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StevedoreError.remote(.connectionFailed(detail: "Non-HTTP response"))
        }

        var responseHeaders: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            if let k = key as? String, let v = value as? String {
                responseHeaders[k] = v
            }
        }

        return WebDAVResponse(
            statusCode: httpResponse.statusCode,
            headers: responseHeaders,
            body: data.isEmpty ? nil : data
        )
    }

    // MARK: - Private helpers

    private func applyAuth(to request: inout URLRequest) {
        switch self.auth {
        case .password(let user, let pass):
            let credentials = Data("\(user):\(pass)".utf8).base64EncodedString()
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        case .bearerToken(let token):
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        default:
            break
        }
    }
}
