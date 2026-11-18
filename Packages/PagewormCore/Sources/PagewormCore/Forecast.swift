import Foundation

public struct ReadingPace: Equatable, Sendable {
    public var pagesPerHour: Double
    public var dailyMinutes: Double
    public var typicalSessionMinutes: Double

    public init(pagesPerHour: Double, dailyMinutes: Double, typicalSessionMinutes: Double) {
        self.pagesPerHour = pagesPerHour
        self.dailyMinutes = dailyMinutes
        self.typicalSessionMinutes = typicalSessionMinutes
    }
}

public struct FinishForecast: Equatable, Sendable {
    public var remainingPages: Int
    public var hoursRemaining: Double
    public var sessionsRemaining: Int
    public var daysRemaining: Int
    public var finishDate: Date
    public var pagesPerDay: Double
    public var swappedHourPages: Double
    public var swappedDaysRemaining: Int
    public var swappedFinishDate: Date

    public init(
        remainingPages: Int,
        hoursRemaining: Double,
        sessionsRemaining: Int,
        daysRemaining: Int,
        finishDate: Date,
        pagesPerDay: Double,
        swappedHourPages: Double,
        swappedDaysRemaining: Int,
        swappedFinishDate: Date
    ) {
        self.remainingPages = remainingPages
        self.hoursRemaining = hoursRemaining
        self.sessionsRemaining = sessionsRemaining
        self.daysRemaining = daysRemaining
        self.finishDate = finishDate
        self.pagesPerDay = pagesPerDay
        self.swappedHourPages = swappedHourPages
        self.swappedDaysRemaining = swappedDaysRemaining
        self.swappedFinishDate = swappedFinishDate
    }
}

public struct WeekStats: Equatable, Sendable {
    public var pages: Int
    public var minutes: Int
    public var sessions: Int

    public init(pages: Int, minutes: Int, sessions: Int) {
        self.pages = pages
        self.minutes = minutes
        self.sessions = sessions
    }
}

public enum ForecastMath {
    public static let defaultPagesPerHour: Double = 30
    public static let defaultSessionMinutes: Double = 25
    public static let assumedPagesPerBook: Int = 320

    public static func pagesPerHour(pages: Int, durationSeconds: Int) -> Double? {
        guard pages > 0, durationSeconds >= 60 else { return nil }
        return Double(pages) / (Double(durationSeconds) / 3600)
    }

    public static func aggregatePagesPerHour(samples: [(pages: Int, durationSeconds: Int)]) -> Double? {
        let useful = samples.filter { $0.pages > 0 && $0.durationSeconds >= 60 }
        let pages = useful.reduce(0) { $0 + $1.pages }
        let seconds = useful.reduce(0) { $0 + $1.durationSeconds }
        return pagesPerHour(pages: pages, durationSeconds: seconds)
    }

    public static func averageSessionMinutes(durationSeconds: [Int]) -> Double? {
        let useful = durationSeconds.filter { $0 >= 60 }
        guard !useful.isEmpty else { return nil }
        let total = useful.reduce(0, +)
        return Double(total) / Double(useful.count) / 60
    }

    /// Days are counted so that a book you can finish in today's reading time finishes today.
    public static func forecast(
        remainingPages: Int,
        pace: ReadingPace,
        today: Date,
        swappedDailyHours: Double = 1,
        calendar: Calendar
    ) -> FinishForecast? {
        guard pace.pagesPerHour > 0, pace.dailyMinutes > 0, pace.typicalSessionMinutes > 0 else { return nil }
        let remaining = max(0, remainingPages)
        let hours = Double(remaining) / pace.pagesPerHour
        let sessionHours = pace.typicalSessionMinutes / 60
        let sessions = remaining == 0 ? 0 : Int((hours / sessionHours).rounded(.up))
        let pagesPerDay = pace.pagesPerHour * (pace.dailyMinutes / 60)
        guard pagesPerDay > 0 else { return nil }
        let days = remaining == 0 ? 0 : Int((Double(remaining) / pagesPerDay).rounded(.up))
        let start = calendar.startOfDay(for: today)
        let finishDate = calendar.date(byAdding: .day, value: days == 0 ? 0 : days - 1, to: start) ?? start

        let swappedPages = pace.pagesPerHour * max(0, swappedDailyHours)
        let swappedPerDay = pagesPerDay + swappedPages
        let swappedDays = remaining == 0 || swappedPerDay <= 0
            ? days
            : Int((Double(remaining) / swappedPerDay).rounded(.up))
        let swappedDate = calendar.date(byAdding: .day, value: swappedDays == 0 ? 0 : swappedDays - 1, to: start) ?? start

        return FinishForecast(
            remainingPages: remaining,
            hoursRemaining: hours,
            sessionsRemaining: sessions,
            daysRemaining: days,
            finishDate: finishDate,
            pagesPerDay: pagesPerDay,
            swappedHourPages: swappedPages,
            swappedDaysRemaining: swappedDays,
            swappedFinishDate: swappedDate
        )
    }

    public static func shelfDays(remainingPages: Int, pace: ReadingPace) -> Int? {
        guard pace.pagesPerHour > 0, pace.dailyMinutes > 0 else { return nil }
        let remaining = max(0, remainingPages)
        if remaining == 0 { return 0 }
        let pagesPerDay = pace.pagesPerHour * (pace.dailyMinutes / 60)
        guard pagesPerDay > 0 else { return nil }
        return Int((Double(remaining) / pagesPerDay).rounded(.up))
    }

    public static func remainingPages(currentPage: Int, totalPages: Int?) -> Int? {
        guard let totalPages, totalPages > 0 else { return nil }
        return max(0, totalPages - max(0, currentPage))
    }
}

public enum WeekMath {
    public static func summarize(
        sessions: [(endedAt: Date, pages: Int, durationSeconds: Int)],
        now: Date,
        calendar: Calendar
    ) -> WeekStats {
        guard let start = calendar.date(byAdding: .day, value: -7, to: now) else {
            return WeekStats(pages: 0, minutes: 0, sessions: 0)
        }
        let relevant = sessions.filter { $0.endedAt >= start && $0.endedAt <= now }
        let seconds = relevant.reduce(0) { $0 + max(0, $1.durationSeconds) }
        return WeekStats(
            pages: relevant.reduce(0) { $0 + max(0, $1.pages) },
            minutes: seconds / 60,
            sessions: relevant.count
        )
    }
}

public enum ChapterMath {
    public static let defaultLength = 20

    public static func nextBoundary(currentPage: Int, totalPages: Int?, chapterLength: Int) -> Int {
        let length = max(chapterLength, 1)
        let page = max(currentPage, 0)
        let boundary = ((page / length) + 1) * length
        if let totalPages, totalPages > 0 {
            return min(boundary, totalPages)
        }
        return boundary
    }

    public static func pagesLeft(currentPage: Int, totalPages: Int?, chapterLength: Int) -> Int {
        max(0, nextBoundary(currentPage: currentPage, totalPages: totalPages, chapterLength: chapterLength) - max(currentPage, 0))
    }
}
