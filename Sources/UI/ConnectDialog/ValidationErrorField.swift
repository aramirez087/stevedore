/// Identifies which form field has a validation error.
///
/// Top-level enum to satisfy SwiftLint's `nesting` rule.
public enum ValidationErrorField: String, Sendable, Hashable {
    case hostname
    case port
    case username
    case sshKeyURL
    case awsAccessKeyID
    case awsSecretKey
    case s3Bucket
    case s3Region
}

/// A single field validation failure with a human-readable message.
public struct ValidationError: Sendable, Equatable {
    public let field: ValidationErrorField
    public let message: String

    public init(field: ValidationErrorField, message: String) {
        self.field = field
        self.message = message
    }
}
