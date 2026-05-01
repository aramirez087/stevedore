import ServicesLogging
import XCTest

final class RedactionTests: XCTestCase {
    // MARK: - Sensitive patterns redacted

    func testAWSAccessKeyRedacted() {
        let input = "key AKIAIOSFODNN7EXAMPLE used"
        let output = Redaction.redact(input)
        XCTAssertFalse(output.contains("AKIAIOSFODNN7EXAMPLE"))
        XCTAssertTrue(output.contains("[REDACTED-AWS-KEY]"))
    }

    func testJWTRedacted() {
        // Minimal well-formed JWT: header.payload.signature (all base64url)
        let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyMTIzIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        let output = Redaction.redact("token: \(jwt)")
        XCTAssertFalse(output.contains(jwt))
        XCTAssertTrue(output.contains("[REDACTED-JWT]"))
    }

    func testBearerTokenRedacted() {
        let input = "Authorization: Bearer abc123def456ghi789jkl"
        let output = Redaction.redact(input)
        XCTAssertTrue(output.contains("[REDACTED-BEARER]"))
        XCTAssertFalse(output.contains("abc123def456ghi789jkl"))
    }

    func testPOSIXUserPathRedacted() {
        let input = "/Users/alice/Documents/file.txt"
        let output = Redaction.redact(input)
        XCTAssertEqual(output, "~/Documents/file.txt")
    }

    func testSSHPassphraseRedacted() {
        let input = "passphrase: hunter2"
        let output = Redaction.redact(input)
        XCTAssertTrue(output.contains("[REDACTED]"))
        XCTAssertFalse(output.contains("hunter2"))
        XCTAssertTrue(output.hasPrefix("passphrase:"))
    }

    func testPasswordKeywordRedacted() {
        let output = Redaction.redact("password=supersecret123")
        XCTAssertFalse(output.contains("supersecret123"))
        XCTAssertTrue(output.contains("[REDACTED]"))
    }

    func testSecretKeywordRedacted() {
        let output = Redaction.redact("secret: my-api-key-value")
        XCTAssertFalse(output.contains("my-api-key-value"))
        XCTAssertTrue(output.contains("[REDACTED]"))
    }

    // MARK: - False positives: safe strings are unchanged

    func testShortAKIANotRedacted() {
        let input = "AKIA1234"
        XCTAssertEqual(Redaction.redact(input), input)
    }

    func testSystemLibraryPathNotRedacted() {
        let input = "/System/Library/Frameworks"
        XCTAssertEqual(Redaction.redact(input), input)
    }

    func testPlainTextUnchanged() {
        let input = "this is a normal log message"
        XCTAssertEqual(Redaction.redact(input), input)
    }

    func testEmptyStringUnchanged() {
        XCTAssertEqual(Redaction.redact(""), "")
    }

    func testBearerShortTokenNotRedacted() {
        // Token shorter than 20 chars should not be redacted
        let input = "Bearer shorttoken"
        XCTAssertEqual(Redaction.redact(input), input)
    }
}
