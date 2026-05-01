@testable import Core
import XCTest

final class ByteCountFormatterTests: XCTestCase {
    // MARK: - Binary mode

    private let binary = ByteSizeFormatter(mode: .binary, locale: Locale(identifier: "en_US_POSIX"))

    func testBinary_zero() {
        let result = self.binary.string(fromBytes: 0)
        // Foundation uses "Zero KB" in binary mode — just verify it is non-empty.
        XCTAssertFalse(result.isEmpty)
    }

    func testBinary_oneByte() {
        let reference = self.makeFormatter(style: .binary)
        XCTAssertEqual(self.binary.string(fromBytes: 1), reference.string(fromByteCount: 1))
    }

    func testBinary_1023() {
        let reference = self.makeFormatter(style: .binary)
        XCTAssertEqual(self.binary.string(fromBytes: 1023), reference.string(fromByteCount: 1023))
    }

    func testBinary_boundary_1024() {
        let reference = self.makeFormatter(style: .binary)
        XCTAssertEqual(self.binary.string(fromBytes: 1024), reference.string(fromByteCount: 1024))
    }

    func testBinary_halfKiB() {
        let reference = self.makeFormatter(style: .binary)
        XCTAssertEqual(self.binary.string(fromBytes: 1536), reference.string(fromByteCount: 1536))
    }

    func testBinary_maxInt64_doesNotCrash() {
        let result = self.binary.string(fromBytes: Int64.max)
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Decimal mode

    private let decimal = ByteSizeFormatter(mode: .decimal, locale: Locale(identifier: "en_US_POSIX"))

    func testDecimal_999() {
        let reference = self.makeFormatter(style: .decimal)
        XCTAssertEqual(self.decimal.string(fromBytes: 999), reference.string(fromByteCount: 999))
    }

    func testDecimal_boundary_1000() {
        let reference = self.makeFormatter(style: .decimal)
        XCTAssertEqual(self.decimal.string(fromBytes: 1000), reference.string(fromByteCount: 1000))
    }

    // MARK: - Negative values

    func testNegative_hasLeadingMinus() {
        let result = self.binary.string(fromBytes: -1024)
        XCTAssertTrue(result.hasPrefix("-"), "Expected leading '-' for negative byte counts")
    }

    // MARK: - FileAttributes helper

    func testString_fromAttributes_nil() {
        let attrs = FileAttributes(sizeInBytes: nil)
        XCTAssertNil(self.binary.string(from: attrs))
    }

    func testString_fromAttributes_nonNil() throws {
        let attrs = FileAttributes(sizeInBytes: 1024)
        let result = self.binary.string(from: attrs)
        XCTAssertNotNil(result)
        XCTAssertFalse(try XCTUnwrap(result?.isEmpty))
    }

    // MARK: - Mode enum

    func testAllModesHaveCaseIterable() {
        XCTAssertEqual(ByteSizeFormatter.Mode.allCases.count, 2)
    }

    // MARK: - Additional boundary tests

    func testBinary_largeMiB() {
        let reference = self.makeFormatter(style: .binary)
        let bytes: Int64 = 10 * 1024 * 1024 // 10 MiB
        XCTAssertEqual(self.binary.string(fromBytes: bytes), reference.string(fromByteCount: bytes))
    }

    func testDecimal_largeGB() {
        let reference = self.makeFormatter(style: .decimal)
        let bytes: Int64 = 2_000_000_000 // 2 GB
        XCTAssertEqual(self.decimal.string(fromBytes: bytes), reference.string(fromByteCount: bytes))
    }

    func testBinary_negativeSmall() {
        let result = self.binary.string(fromBytes: -1)
        XCTAssertTrue(result.hasPrefix("-"))
    }

    func testHashableConformance() {
        let a = ByteSizeFormatter(mode: .binary)
        let b = ByteSizeFormatter(mode: .binary)
        XCTAssertEqual(a, b)
        let c = ByteSizeFormatter(mode: .decimal)
        XCTAssertNotEqual(a, c)
    }

    func testAllowsZeroRepresentation_false() {
        let f = ByteSizeFormatter(mode: .binary, allowsZeroRepresentation: false)
        // Just confirm it returns a string without crashing.
        XCTAssertFalse(f.string(fromBytes: 0).isEmpty)
    }

    // MARK: - Helpers

    private func makeFormatter(style: ByteCountFormatter.CountStyle) -> ByteCountFormatter {
        let f = ByteCountFormatter()
        f.countStyle = style
        f.allowsNonnumericFormatting = true
        return f
    }
}
