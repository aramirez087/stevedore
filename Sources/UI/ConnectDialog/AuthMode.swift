/// Authentication modes available for remote connections.
///
/// Top-level enum to satisfy SwiftLint's `nesting` rule (not nested inside ViewModel).
public enum AuthMode: String, CaseIterable, Sendable, Hashable {
    case password
    case sshKey
    case iam
    case anonymous
}

public extension AuthMode {
    /// Human-readable label shown in the segmented picker.
    var label: String {
        switch self {
        case .password: "Password"
        case .sshKey: "SSH Key"
        case .iam: "IAM"
        case .anonymous: "Anonymous"
        }
    }
}
