/// Current status of the test-connection action.
public enum TestConnectionStatus: Sendable, Equatable {
    case idle
    case testing
    case success(latencyMilliseconds: Int?)
    case failure(message: String)

    public var isSuccess: Bool {
        guard case .success = self else { return false }
        return true
    }

    public var userMessage: String {
        switch self {
        case .idle:
            return ""
        case .testing:
            return "Testing connection…"
        case .success(let latency):
            if let ms = latency {
                return "Connection successful (\(ms) ms)."
            }
            return "Connection successful."
        case .failure(let message):
            return message
        }
    }
}
