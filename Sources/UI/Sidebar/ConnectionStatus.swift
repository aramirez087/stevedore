/// Live status of a remote connection session.
public enum ConnectionStatus: Hashable, Sendable {
    case idle
    case connecting
    case connected
    case error(String)
}
