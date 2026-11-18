import Foundation
import PagewormCore

struct ReadingProgress {
    var books: [Book]
    var sessions: [ReadingSessionRecord]
    var profile: UserProfile
    var now: Date

    var calendar: Calendar { PagewormCalendar.make() }
    var gate: FeatureGate { FeatureGate(isPremium: profile.isPremium) }
    var pagesPerHour: Double {
        ReadingStats.aggregatePagesPerHour(sessions.map { SpeedSample(pages: $0.pages, minutes: $0.minutes) })
    }

    var qualifyingDays: Set<Date> {
        Set(sessions.compactMap { session in
            session.minutes * 60 >= UnlockPolicy.minimumSessionSeconds ? session.endedAt : nil
        })
    }

    var streak: StreakEvaluation {
        StreakCalculator.evaluate(
            readingDays: qualifyingDays,
            today: now,
            calendar: calendar,
            allowsFreeze: gate.allows(.streakFreeze)
        )
    }

    var finishedBooks: Int { books.filter { $0.finishedAt != nil }.count }
    var realStage: InkyStage { InkyStage.stage(streak: streak.currentStreak, finishedBooks: finishedBooks) }
    var stage: InkyStage {
        InkyStage.visibleStage(streak: streak.currentStreak, finishedBooks: finishedBooks, isPremium: profile.isPremium)
    }

    var lastSessionEndedAt: Date? { sessions.map(\.endedAt).max() }
    var justFinishedBook: Bool {
        books.contains { book in
            guard let finishedAt = book.finishedAt else { return false }
            return now.timeIntervalSince(finishedAt) < 12 * 60 * 60
        }
    }

    var mood: InkyMood {
        InkyMoodDecider.mood(
            now: now,
            lastSessionEndedAt: lastSessionEndedAt,
            readToday: streak.readToday,
            justFinishedBook: justFinishedBook,
            calendar: calendar
        )
    }

    var currentBook: Book? {
        if let current = books.first(where: { $0.isCurrent && $0.finishedAt == nil }) {
            return current
        }
        return books.first { $0.shelf == .currentlyReading && $0.finishedAt == nil }
            ?? books.first { $0.shelf == .toRead }
    }

    func forecast(for book: Book) -> FinishForecast? {
        guard let pageCount = book.pageCount else { return nil }
        return ForecastMath.forecast(
            currentPage: book.currentPage,
            pageCount: pageCount,
            pagesPerHour: pagesPerHour,
            minutesPerDay: max(profile.dailyReadingMinutes, 1),
            now: now,
            calendar: calendar
        )
    }

    var shelfCountdown: TBRCountdown {
        TBRMath.countdown(
            books: books.map { ShelfBook(pageCount: $0.pageCount, currentPage: $0.currentPage, shelf: $0.shelf) },
            pagesPerHour: pagesPerHour,
            minutesPerDay: profile.dailyReadingMinutes
        )
    }

    var weekPages: Int {
        sessions.filter { now.timeIntervalSince($0.endedAt) < 7 * 24 * 60 * 60 }.reduce(0) { $0 + $1.pages }
    }

    var weekMinutes: Int {
        Int(sessions.filter { now.timeIntervalSince($0.endedAt) < 7 * 24 * 60 * 60 }.reduce(0) { $0 + $1.minutes }.rounded())
    }

    func line() -> String {
        let name = profile.name.isEmpty ? "friend" : profile.name
        switch mood {
        case .happy:
            if streak.currentStreak > 1 {
                return "Day \(streak.currentStreak). I kept your place, \(name)."
            }
            return "I'm here, \(name). The book is too."
        case .sleepy:
            return "That chapter made me sleepy. A good kind of sleepy."
        case .missingYou:
            return "I missed you, \(name). The bookmark hasn't moved."
        case .cheering:
            return "You finished it. I'm doing a little wiggle."
        }
    }
}
