import Core

public extension Credential {
    /// Returns a description suitable for logging that never exposes the secret payload.
    var redactedDescription: String {
        let usernameDisplay = self.username.map { "\"\($0)\"" } ?? "nil"
        return "Credential(username: \(usernameDisplay), material: \(self.material.redactedDescription))"
    }
}

public extension CredentialMaterial {
    /// Returns a type-only label; the secret value is never included.
    var redactedDescription: String {
        switch self {
        case .password: "<password [redacted]>"
        case .privateKey: "<privateKey [redacted]>"
        case .oauthToken: "<oauthToken [redacted]>"
        }
    }
}
