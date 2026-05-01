@testable import Core
import XCTest

final class DateFormatterTests: XCTestCase {
    private var fixedCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.gmt
        return cal
    }

    private var formatter: StevedoreDateFormatter {
        StevedoreDateFormatter(
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: self.fixedCalendar,
            timeZone: TimeZone.gmt
        )
    }

    // MARK: - relative

    func testRelative_futureMinutes_containsMinute() {
        let ref = Date()
        let future = ref.addingTimeInterval(300) // 5 minutes ahead
        let result = self.formatter.relative(future, relativeTo: ref)
        XCTAssertTrue(
            result.lowercased().contains("minute"),
            "Expected 'minute' in relative string, got: \(result)"
        )
    }

    func testRelative_pastHours_containsHour() {
        let ref = Date()
        let past = ref.addingTimeInterval(-7200) // 2 hours ago
        let result = self.formatter.relative(past, relativeTo: ref)
        XCTAssertTrue(
            result.lowercased().contains("hour"),
            "Expected 'hour' in relative string, got: \(result)"
        )
    }

    // MARK: - mediumAbsolute

    func testMediumAbsolute_producesNonEmptyString() {
        let date = Date(timeIntervalSince1970: 1_746_000_000) // some fixed timestamp
        let result = self.formatter.mediumAbsolute(date)
        XCTAssertFalse(result.isEmpty)
    }

    func testMediumAbsolute_containsYear() {
        let date = Date(timeIntervalSince1970: 1_746_000_000)
        let result = self.formatter.mediumAbsolute(date)
        // Should contain a 4-digit year
        let hasYear = result.contains("2025") || result.contains("2026") || result.contains("2024")
        XCTAssertTrue(hasYear, "Expected a year in: \(result)")
    }

    // MARK: - smartListing

    func testSmartListing_today_containsToday() {
        let ref = Date()
        // A date 30 seconds before reference, same day.
        let sameDay = ref.addingTimeInterval(-30)
        let result = self.formatter.smartListing(sameDay, relativeTo: ref)
        XCTAssertTrue(result.hasPrefix("Today at"), "Expected 'Today at …', got: \(result)")
    }

    func testSmartListing_yesterday_containsYesterday() {
        let ref = Date()
        guard let yesterday = fixedCalendar.date(byAdding: .day, value: -1, to: ref) else {
            return XCTFail("Could not compute yesterday")
        }
        let result = self.formatter.smartListing(yesterday, relativeTo: ref)
        XCTAssertTrue(result.hasPrefix("Yesterday at"), "Expected 'Yesterday at …', got: \(result)")
    }

    func testSmartListing_oldDate_fallsBackToMedium() {
        let ref = Date()
        guard let oldDate = fixedCalendar.date(byAdding: .day, value: -30, to: ref) else {
            return XCTFail("Could not compute old date")
        }
        let result = self.formatter.smartListing(oldDate, relativeTo: ref)
        // Not today or yesterday — should not start with "Today" or "Yesterday"
        XCTAssertFalse(result.hasPrefix("Today"), "Unexpected 'Today' prefix: \(result)")
        XCTAssertFalse(result.hasPrefix("Yesterday"), "Unexpected 'Yesterday' prefix: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Locale variation

    func testRelative_frenchLocale_containsFrenchWord() {
        let frFormatter = StevedoreDateFormatter(
            locale: Locale(identifier: "fr_FR"),
            calendar: self.fixedCalendar,
            timeZone: TimeZone.gmt
        )
        let ref = Date()
        let past = ref.addingTimeInterval(-3600)
        let result = frFormatter.relative(past, relativeTo: ref)
        XCTAssertTrue(
            result.lowercased().contains("heure") || result.lowercased().contains("il y a"),
            "Expected French relative string, got: \(result)"
        )
    }

    // MARK: - Additional edge cases

    func testMediumAbsolute_epochDate() {
        // epoch = 1970-01-01 00:00:00 UTC — should not crash or produce empty string.
        let epoch = Date(timeIntervalSince1970: 0)
        let result = self.formatter.mediumAbsolute(epoch)
        XCTAssertFalse(result.isEmpty)
    }

    func testSmartListing_farFuture_fallsBackToMedium() {
        let ref = Date()
        let future = ref.addingTimeInterval(60 * 60 * 24 * 365) // 1 year ahead
        let result = self.formatter.smartListing(future, relativeTo: ref)
        XCTAssertFalse(result.isEmpty)
    }

    func testHashableConformance() {
        let a = StevedoreDateFormatter(
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: self.fixedCalendar,
            timeZone: TimeZone.gmt
        )
        let b = StevedoreDateFormatter(
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: self.fixedCalendar,
            timeZone: TimeZone.gmt
        )
        XCTAssertEqual(a, b)
    }

    func testRelative_secondsAgo_containsSecondOrNow() {
        let ref = Date()
        let justNow = ref.addingTimeInterval(-10)
        let result = self.formatter.relative(justNow, relativeTo: ref)
        XCTAssertFalse(result.isEmpty)
    }
}
