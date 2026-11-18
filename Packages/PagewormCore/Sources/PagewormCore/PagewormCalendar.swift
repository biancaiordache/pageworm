import Foundation

public enum PagewormCalendar {
    /// Monday-based weeks so the streak freeze lines up with "this week" in the UI.
    public static func make(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    public static func utc() -> Calendar {
        make(timeZone: TimeZone(secondsFromGMT: 0)!)
    }
}
