import XCTest
@testable import PagewormCore

final class ForecastTests: XCTestCase {
    func testFinishForecastAndSwappedHour() throws {
        let calendar = utcCalendar()
        let today = date(2024, 1, 1, calendar: calendar)
        let pace = ReadingPace(pagesPerHour: 50, dailyMinutes: 30, typicalSessionMinutes: 25)
        let forecast = try XCTUnwrap(ForecastMath.forecast(remainingPages: 100, pace: pace, today: today, calendar: calendar))
        XCTAssertEqual(forecast.hoursRemaining, 2, accuracy: 0.0001)
        XCTAssertEqual(forecast.sessionsRemaining, 5)
        XCTAssertEqual(forecast.pagesPerDay, 25, accuracy: 0.0001)
        XCTAssertEqual(forecast.daysRemaining, 4)
        XCTAssertEqual(forecast.finishDate, date(2024, 1, 4, calendar: calendar))
        XCTAssertEqual(forecast.swappedHourPages, 50, accuracy: 0.0001)
        XCTAssertEqual(forecast.swappedDaysRemaining, 2)
        XCTAssertEqual(forecast.swappedFinishDate, date(2024, 1, 2, calendar: calendar))
    }

    func testFinishedBookForecastIsToday() throws {
        let calendar = utcCalendar()
        let today = date(2024, 6, 1, 15, calendar: calendar)
        let pace = ReadingPace(pagesPerHour: 30, dailyMinutes: 20, typicalSessionMinutes: 20)
        let forecast = try XCTUnwrap(ForecastMath.forecast(remainingPages: 0, pace: pace, today: today, calendar: calendar))
        XCTAssertEqual(forecast.daysRemaining, 0)
        XCTAssertEqual(forecast.sessionsRemaining, 0)
        XCTAssertEqual(forecast.finishDate, calendar.startOfDay(for: today))
    }

    func testAggregateSpeedIgnoresTinySamples() {
        let speed = ForecastMath.aggregatePagesPerHour(samples: [
            (pages: 10, durationSeconds: 30),
            (pages: 30, durationSeconds: 3600),
            (pages: 15, durationSeconds: 1800)
        ])
        XCTAssertEqual(speed ?? 0, 30, accuracy: 0.001)
        XCTAssertNil(ForecastMath.pagesPerHour(pages: 0, durationSeconds: 3600))
        XCTAssertNil(ForecastMath.pagesPerHour(pages: 5, durationSeconds: 30))
    }

    func testShelfCountdownAndWeekStats() {
        let pace = ReadingPace(pagesPerHour: 40, dailyMinutes: 30, typicalSessionMinutes: 25)
        XCTAssertEqual(ForecastMath.shelfDays(remainingPages: 80, pace: pace), 4)
        XCTAssertEqual(ForecastMath.shelfDays(remainingPages: 0, pace: pace), 0)
        XCTAssertEqual(InkyCopy.shelfLine(days: 4), "Your shelf is 4 days at your pace.")

        let calendar = utcCalendar()
        let now = date(2024, 3, 10, 12, calendar: calendar)
        let stats = WeekMath.summarize(
            sessions: [
                (endedAt: date(2024, 3, 4, 12, calendar: calendar), pages: 10, durationSeconds: 600),
                (endedAt: date(2024, 3, 2, 12, calendar: calendar), pages: 99, durationSeconds: 600),
                (endedAt: now, pages: 5, durationSeconds: 120)
            ],
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(stats.sessions, 2)
        XCTAssertEqual(stats.pages, 15)
        XCTAssertEqual(stats.minutes, 12)
    }

    func testChapterBoundaries() {
        XCTAssertEqual(ChapterMath.pagesLeft(currentPage: 0, totalPages: 320, chapterLength: 20), 20)
        XCTAssertEqual(ChapterMath.pagesLeft(currentPage: 20, totalPages: 320, chapterLength: 20), 20)
        XCTAssertEqual(ChapterMath.pagesLeft(currentPage: 310, totalPages: 320, chapterLength: 20), 10)
        XCTAssertEqual(ChapterMath.pagesLeft(currentPage: 320, totalPages: 320, chapterLength: 20), 0)
    }

    func testShockMath() {
        let shock = ShockMath.calculate(dailyPhoneHours: 4, yearsRemaining: 50, pagesPerBook: 320, pagesPerHour: 30)
        XCTAssertEqual(shock.yearsOnPhone, 4 * 50 / 24, accuracy: 0.0001)
        XCTAssertEqual(shock.booksMissed, 6848)
        XCTAssertEqual(InkyCopy.shockYears(shock), "At this rate you'll spend 8.3 years of your life on your phone.")
        XCTAssertEqual(InkyCopy.shockBooks(shock), "That's 6,848 books you could read.")
    }

    func testSessionQualificationAndScrollCopy() {
        XCTAssertTrue(SessionRules.qualifies(durationSeconds: 5 * 60, pagesRead: 1))
        XCTAssertFalse(SessionRules.qualifies(durationSeconds: 5 * 60 - 1, pagesRead: 10))
        XCTAssertFalse(SessionRules.qualifies(durationSeconds: 20 * 60, pagesRead: 0))
        XCTAssertEqual(SessionRules.pagesRead(start: 12, end: 18), 6)
        XCTAssertEqual(ScrollToBooks.summary(appName: "TikTok", hours: 4, pagesPerHour: 29.5), "4h back from TikTok is 118 pages")
    }
}
