import Foundation

public enum DateParsing {
    /// Parses export dates. Year-first (`2021/05/10`, `2021-05-10`) always wins.
    /// When the year is last, Goodreads prefers month/day and StoryGraph prefers day/month.
    /// Unambiguous values (one component > 12) are accepted either way.
    public static func parse(_ raw: String, preferDayFirst: Bool, calendar: Calendar) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(whereSeparator: { $0 == "/" || $0 == "-" || $0 == "." }).map(String.init)
        guard parts.count >= 3, let first = Int(parts[0]), let second = Int(parts[1]), let third = Int(parts[2]) else {
            return nil
        }

        let year: Int
        let month: Int
        let day: Int
        if parts[0].count == 4 {
            year = first
            month = second
            day = third
        } else if parts[2].count == 4 {
            year = third
            if first > 12 {
                day = first
                month = second
            } else if second > 12 {
                month = first
                day = second
            } else if preferDayFirst {
                day = first
                month = second
            } else {
                month = first
                day = second
            }
        } else {
            return nil
        }

        guard (1...12).contains(month), (1...31).contains(day), (1...9999).contains(year) else { return nil }
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }
}
