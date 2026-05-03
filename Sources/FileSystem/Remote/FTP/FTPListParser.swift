import Foundation

/// A single entry returned by an FTP directory listing.
public struct FTPEntry: Sendable, Hashable {
    public let name: String
    public let isDirectory: Bool
    public let sizeInBytes: Int64?
    public let modificationDate: Date?
    public let permissions: String?

    public init(
        name: String,
        isDirectory: Bool,
        sizeInBytes: Int64? = nil,
        modificationDate: Date? = nil,
        permissions: String? = nil
    ) {
        self.name = name
        self.isDirectory = isDirectory
        self.sizeInBytes = sizeInBytes
        self.modificationDate = modificationDate
        self.permissions = permissions
    }
}

/// Pure parser for FTP directory listing formats (no networking).
public enum FTPListParser {
    // MARK: - Unix LIST

    /// Parses Unix-style `LIST` responses.
    /// Example: `drwxr-xr-x 2 user group 4096 Jan  1 12:00 dirname`
    public static func parseListResponse(
        _ response: String,
        encoding: String.Encoding = .utf8
    ) -> [FTPEntry] {
        response.components(separatedBy: "\n").compactMap { self.parseListLine($0) }
    }

    // MARK: - MLSD

    /// Parses RFC 3659 `MLSD` responses (semicolon-separated key=value facts).
    /// Example: `type=dir;size=0;modify=20240101120000; dirname`
    public static func parseMLSDResponse(_ response: String) -> [FTPEntry] {
        response.components(separatedBy: "\n").compactMap { self.parseMLSDLine($0) }
    }

    // MARK: - Private parsers

    private static func parseListLine(_ line: String) -> FTPEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Windows-style: "05-01-24  12:00PM <DIR> dirname"
        if let entry = parseWindowsListLine(trimmed) { return entry }

        // Unix-style: "drwxr-xr-x 2 user group 4096 Jan  1 12:00 dirname"
        return self.parseUnixListLine(trimmed)
    }

    private static func parseUnixListLine(_ line: String) -> FTPEntry? {
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 9 else { return nil }

        let permsStr = String(parts[0])
        guard permsStr.count >= 1 else { return nil }

        let isDirectory = permsStr.hasPrefix("d")
        let isSymlink = permsStr.hasPrefix("l")
        let sizeStr = parts.count > 4 ? String(parts[4]) : nil
        let size = sizeStr.flatMap { Int64($0) }

        // Name is everything after the 8th whitespace-delimited field.
        // We scan the original string character-by-character so double spaces
        // (used for alignment in ls-style output) don't corrupt the offset.
        var fieldCount = 0
        var cursor = line.startIndex
        while cursor < line.endIndex, fieldCount < 8 {
            while cursor < line.endIndex, line[cursor] == " " {
                cursor = line.index(after: cursor)
            }
            while cursor < line.endIndex, line[cursor] != " " {
                cursor = line.index(after: cursor)
            }
            fieldCount += 1
        }
        while cursor < line.endIndex, line[cursor] == " " {
            cursor = line.index(after: cursor)
        }
        let nameStr = cursor < line.endIndex
            ? String(line[cursor...]).trimmingCharacters(in: .whitespacesAndNewlines)
            : String(parts[parts.count - 1])

        // For symlinks, strip " -> target" suffix.
        let finalName: String = if isSymlink, let arrowRange = nameStr.range(of: " -> ") {
            String(nameStr[..<arrowRange.lowerBound])
        } else {
            nameStr
        }

        guard !finalName.isEmpty, finalName != ".", finalName != ".." else { return nil }

        // Parse modification date from months/day/time fields (parts 5, 6, 7).
        let modDate: Date?
        if parts.count >= 8 {
            let monthStr = String(parts[5])
            let dayStr = String(parts[6])
            let yearOrTime = String(parts[7])
            modDate = self.parseUnixDate(month: monthStr, day: dayStr, yearOrTime: yearOrTime)
        } else {
            modDate = nil
        }

        return FTPEntry(
            name: finalName,
            isDirectory: isDirectory,
            sizeInBytes: size,
            modificationDate: modDate,
            permissions: permsStr
        )
    }

    private static func parseWindowsListLine(_ line: String) -> FTPEntry? {
        // Pattern: MM-DD-YY  HH:MMAM/PM  <DIR>  name  OR size  name
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 4 else { return nil }
        // Date is parts[0], time is parts[1], <DIR> or size is parts[2]
        guard parts[0].contains("-"), parts[1].contains(":") else { return nil }

        let isDir = parts[2] == "<DIR>"
        let size = isDir ? nil : Int64(String(parts[2]))
        let name = parts.dropFirst(3).joined(separator: " ")
        guard !name.isEmpty else { return nil }

        return FTPEntry(name: name, isDirectory: isDir, sizeInBytes: size)
    }

    private static func parseMLSDLine(_ line: String) -> FTPEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // MLSD format: "facts; name" — facts end at the first space.
        guard let spaceIdx = trimmed.firstIndex(of: " ") else { return nil }
        let factsStr = String(trimmed[..<spaceIdx])
        let name = String(trimmed[trimmed.index(after: spaceIdx)...])
            .trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, name != ".", name != ".." else { return nil }

        var isDirectory = false
        var size: Int64?
        var modDate: Date?

        for fact in factsStr.components(separatedBy: ";") {
            let kv = fact.components(separatedBy: "=")
            guard kv.count == 2 else { continue }
            let key = kv[0].lowercased()
            let value = kv[1]
            switch key {
            case "type":
                isDirectory = ["dir", "cdir", "pdir"].contains(value.lowercased())
            case "size":
                size = Int64(value)
            case "modify":
                modDate = self.parseMLSDDate(value)
            default:
                break
            }
        }

        return FTPEntry(name: name, isDirectory: isDirectory, sizeInBytes: size, modificationDate: modDate)
    }

    // MARK: - Date helpers

    private static let unixMonths = [
        "jan": 1, "feb": 2, "mar": 3, "apr": 4,
        "may": 5, "jun": 6, "jul": 7, "aug": 8,
        "sep": 9, "oct": 10, "nov": 11, "dec": 12,
    ]

    private static func parseUnixDate(month: String, day: String, yearOrTime: String) -> Date? {
        guard let m = unixMonths[month.lowercased()], let d = Int(day) else { return nil }
        var comps = DateComponents()
        comps.month = m
        comps.day = d
        if yearOrTime.contains(":") {
            let timeParts = yearOrTime.components(separatedBy: ":")
            comps.hour = Int(timeParts[0])
            comps.minute = Int(timeParts.dropFirst().first ?? "0")
            comps.year = Calendar.current.component(.year, from: Date())
        } else {
            comps.year = Int(yearOrTime)
        }
        return Calendar.current.date(from: comps)
    }

    private static func parseMLSDDate(_ value: String) -> Date? {
        // Format: YYYYMMDDHHmmss[.fraction]
        let s = value.components(separatedBy: ".").first ?? value
        guard s.count >= 14 else { return nil }
        var comps = DateComponents()
        comps.year = Int(s.prefix(4))
        comps.month = Int(s.dropFirst(4).prefix(2))
        comps.day = Int(s.dropFirst(6).prefix(2))
        comps.hour = Int(s.dropFirst(8).prefix(2))
        comps.minute = Int(s.dropFirst(10).prefix(2))
        comps.second = Int(s.dropFirst(12).prefix(2))
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: comps)
    }
}
