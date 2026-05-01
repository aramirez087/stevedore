import Foundation

/// A `Sendable` date-formatting helper.
///
/// All formatters are instantiated inside each method — no stored reference-type
/// state — satisfying both the "pure" constraint and Swift 6 Sendable rules.
public struct StevedoreDateFormatter: Sendable, Hashable {
    public let locale: Locale
    public let calendar: Calendar
    public let timeZone: TimeZone

    public init(
        locale: Locale = .current,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) {
        self.locale = locale
        self.calendar = calendar
        self.timeZone = timeZone
    }

    /// Relative description: "in 5 minutes", "2 hours ago", "yesterday".
    public func relative(_ date: Date, relativeTo reference: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = self.locale
        formatter.calendar = self.calendar
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: reference)
    }

    /// Medium date + short time: "Apr 30, 2026 at 3:14 PM" (en_US).
    public func mediumAbsolute(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = self.locale
        formatter.calendar = self.calendar
        formatter.timeZone = self.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Smart listing: "Today at 3:14 PM" / "Yesterday at 11:00 AM" / `mediumAbsolute`.
    public func smartListing(_ date: Date, relativeTo reference: Date = Date()) -> String {
        var cal = self.calendar
        cal.timeZone = self.timeZone
        let timeOnly = self.timeOnlyString(for: date)
        if cal.isDateInToday(reference) && cal.isDate(date, inSameDayAs: reference) {
            return "Today at \(timeOnly)"
        }
        if cal.isDateInYesterday(reference) || self.isYesterdayRelativeTo(
            date: date,
            reference: reference,
            calendar: cal
        ) {
            return "Yesterday at \(timeOnly)"
        }
        return self.mediumAbsolute(date)
    }

    private func timeOnlyString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = self.locale
        formatter.calendar = self.calendar
        formatter.timeZone = self.timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func isYesterdayRelativeTo(date: Date, reference: Date, calendar: Calendar) -> Bool {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: reference) else {
            return false
        }
        return calendar.isDate(date, inSameDayAs: yesterday)
    }
}
