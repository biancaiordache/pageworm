import Foundation

public struct FinishForecast: Equatable {
    public var remainingPages: Int
    public var pagesPerHour: Double
    public var minutesPerDay: Int
    public var hoursRemaining: Double
    public var sessionsRemaining: Int
    public var finishDate: Date
    public var fasterMinutesPerDay: Int
    public var fasterFinishDate: Date
    public var daysSaved: Int

    public init(
        remainingPages: Int,
        pagesPerHour: Double,
        minutesPerDay: Int,
        hoursRemaining: Double,
        sessionsRemaining: Int,
        finishDate: Date,
        fasterMinutesPerDay: Int,
        fasterFinishDate: Date,
        daysSaved: Int
    ) {
        self.remainingPages = remainingPages
        self.pagesPerHour = pagesPerHour
        self.minutesPerDay = minutesPerDay
        self.hoursRemaining = hoursRemaining
        self.sessionsRemaining = sessionsRemaining
        self.finishDate = finishDate
        self.fasterMinutesPerDay = fasterMinutesPerDay
        self.fasterFinishDate = fasterFinishDate
        self.daysSaved = daysSaved
    }
}

public enum ForecastMath {
    public static let defaultSessionMinutes = 25
    public static let swappedScrollMinutes = 60

    public static func forecast(
        currentPage: Int,
        pageCount: Int,
        pagesPerHour: Double,
        minutesPerDay: Int,
        now: Date,
        calendar: Calendar,
        sessionMinutes: Int = defaultSessionMinutes,
        extraDailyMinutes: Int = swappedScrollMinutes
    ) -> FinishForecast? {
        guard pageCount > currentPage else { return nil }
        let remaining = pageCount - max(currentPage, 0)
        let speed = pagesPerHour > 0 ? pagesPerHour : ReadingStats.defaultPagesPerHour
        let daily = max(minutesPerDay, 1)
        let hours = Double(remaining) / speed
        let sessionHours = Double(max(sessionMinutes, 1)) / 60
        let sessions = max(1, Int((hours / sessionHours).rounded(.up)))
        let finish = finishDate(
            remainingPages: remaining,
            speed: speed,
            minutesPerDay: daily,
            now: now,
            calendar: calendar
        )
        let fasterMinutes = daily + max(extraDailyMinutes, 0)
        let faster = finishDate(
            remainingPages: remaining,
            speed: speed,
            minutesPerDay: fasterMinutes,
            now: now,
            calendar: calendar
        )
        let saved = calendar.dateComponents([.day], from: faster, to: finish).day ?? 0
        return FinishForecast(
            remainingPages: remaining,
            pagesPerHour: speed,
            minutesPerDay: daily,
            hoursRemaining: hours,
            sessionsRemaining: sessions,
            finishDate: finish,
            fasterMinutesPerDay: fasterMinutes,
            fasterFinishDate: faster,
            daysSaved: max(0, saved)
        )
    }

    private static func finishDate(
        remainingPages: Int,
        speed: Double,
        minutesPerDay: Int,
        now: Date,
        calendar: Calendar
    ) -> Date {
        let pagesPerDay = speed * (Double(minutesPerDay) / 60)
        let days = Double(remainingPages) / max(pagesPerDay, 0.01)
        // Subtract a hair so a value that is mathematically whole, but not in binary, does not roll into the next day.
        let wholeDays = Int((days - 0.0000001).rounded(.up))
        let offset = max(0, wholeDays - 1)
        let start = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: offset, to: start) ?? start
    }
}
