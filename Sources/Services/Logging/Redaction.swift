/// Scrubs well-known sensitive patterns from log message strings before they
/// are written to os.Logger or stored in the ring buffer.
///
/// Rules use Swift native Regex literals (build-time compiled, no throwing
/// initialiser) to avoid `try!` which is forbidden by project lint rules.
public enum Redaction {
    // `Regex` is an immutable value type whose internal state (compiled DFA/NFA
    // tables) is written once at initialization and never mutated afterward.
    // Apple's SDK does not yet mark `Regex` as `Sendable`; `nonisolated(unsafe)`
    // is the correct Swift 6 suppression for a provably safe global constant.

    /// AWS IAM Access Key ID: AKIA followed by exactly 16 uppercase alphanumeric chars.
    /// Anchored prefix prevents short strings like "AKIA1234" from matching.
    private nonisolated(unsafe) static let awsKeyRegex = /AKIA[0-9A-Z]{16}/

    /// JSON Web Token: three base64url sections (header.payload.signature),
    /// each identified by the eyJ prefix on the first two sections.
    private nonisolated(unsafe) static let jwtRegex = /eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*/

    /// Bearer tokens: case-insensitive "bearer" followed by 20+ token chars.
    /// Minimum length prevents false positives on short identifiers.
    private nonisolated(unsafe) static let bearerRegex = /(?i)bearer\s+[A-Za-z0-9_.\-]{20,}/

    /// POSIX paths under /Users/<username>/: replaces the user portion with ~.
    /// Uses extended delimiter (#/.../#) to allow literal / in the pattern.
    /// Only /Users/ prefix is matched; system paths (/System/, /usr/) are untouched.
    /// Extended delimiter #/.../#: the pattern content is /Users/[^/\s]+/ (trailing
    /// slash included), so replacement of /Users/alice/ with ~/ gives ~/rest/of/path.
    private nonisolated(unsafe) static let userPathRegex = #//Users/[^/\s]+//#

    /// Password-style key=value pairs: captures the keyword so it is preserved
    /// in the replacement, making the output readable while hiding the secret.
    private nonisolated(unsafe) static let passwordRegex = /(?i)(password|passphrase|passwd|secret)\s*[:=]\s*\S+/

    /// Returns `text` with all recognised sensitive patterns replaced.
    public static func redact(_ text: String) -> String {
        var result = text
        result = result.replacing(Self.awsKeyRegex, with: "[REDACTED-AWS-KEY]")
        result = result.replacing(Self.jwtRegex, with: "[REDACTED-JWT]")
        result = result.replacing(Self.bearerRegex, with: "[REDACTED-BEARER]")
        result = result.replacing(Self.userPathRegex, with: "~/")
        result = result.replacing(Self.passwordRegex) { match in
            "\(match.output.1): [REDACTED]"
        }
        return result
    }
}
