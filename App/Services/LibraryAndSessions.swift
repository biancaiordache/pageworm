import Foundation
import PagewormCore
import PagewormDesign
import SwiftData
import WidgetKit

struct ImportSummary: Equatable {
    var source: LibrarySource
    var added: Int
    var updated: Int
    var skipped: Int
    var toRead: Int
    var reading: Int
    var finished: Int
    var needsPremium: Bool = false

    static let premiumRequired = ImportSummary(
        source: .storyGraph,
        added: 0,
        updated: 0,
        skipped: 0,
        toRead: 0,
        reading: 0,
        finished: 0,
        needsPremium: true
    )
}

enum LibraryImporter {
    @MainActor
    static func importFile(url: URL, context: ModelContext, allowStoryGraph: Bool) -> ImportSummary {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            return ImportSummary(source: .unknown, added: 0, updated: 0, skipped: 0, toRead: 0, reading: 0, finished: 0)
        }
        let text = decode(data)
        let parsed = LibraryCSVParser.parse(text)
        if parsed.source == .storyGraph && !allowStoryGraph {
            return .premiumRequired
        }
        let existing = Store.books(context)
        var added = 0
        var updated = 0
        for item in parsed.books {
            if let match = existing.first(where: { matches($0, item) }) ?? nilMatch(context: context, item: item) {
                apply(item, to: match)
                updated += 1
            } else {
                let book = Book(
                    title: item.title,
                    authors: item.authors,
                    isbn: item.isbn,
                    pageCount: item.pageCount,
                    shelf: item.shelf,
                    source: item.source == .unknown ? .manual : item.source,
                    dateAdded: item.dateAdded ?? Date(),
                    finishedAt: item.shelf == .read ? (item.dateAdded ?? Date()) : nil,
                    countsTowardInky: item.shelf != .read
                )
                context.insert(book)
                added += 1
            }
        }
        try? context.save()
        return ImportSummary(
            source: parsed.source,
            added: added,
            updated: updated,
            skipped: parsed.skipped,
            toRead: parsed.count(on: .toRead),
            reading: parsed.count(on: .currentlyReading),
            finished: parsed.count(on: .read)
        )
    }

    private static func decode(_ data: Data) -> String {
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .utf16) { return text }
        return String(decoding: data, as: UTF8.self)
    }

    @MainActor
    private static func nilMatch(context: ModelContext, item: ImportedBook) -> Book? {
        Store.books(context).first { matches($0, item) }
    }

    private static func matches(_ book: Book, _ item: ImportedBook) -> Bool {
        if let isbn = item.isbn, let existing = book.isbn, isbn == existing { return true }
        return book.title.compare(item.title, options: .caseInsensitive) == .orderedSame
            && book.authors.compare(item.authors, options: .caseInsensitive) == .orderedSame
    }

    private static func apply(_ item: ImportedBook, to book: Book) {
        book.title = item.title
        book.authors = item.authors
        if book.isbn == nil { book.isbn = item.isbn }
        if book.pageCount == nil { book.pageCount = item.pageCount }
        book.shelf = item.shelf
        if item.shelf == .read, book.finishedAt == nil {
            book.finishedAt = item.dateAdded ?? Date()
            book.countsTowardInky = false
        }
    }
}

struct SessionOutcome: Equatable {
    var pages: Int
    var minutes: Int
    var pagesPerHour: Double?
    var qualified: Bool
    var finishedBook: Bool
    var streak: Int
}

enum SessionFinisher {
    @MainActor
    static func finish(
        context: ModelContext,
        book: Book,
        startedAt: Date,
        endedAt: Date,
        startPage: Int,
        endPage: Int,
        isPremium: Bool,
        screenTime: ScreenTimeManager
    ) -> SessionOutcome {
        let seconds = max(0, Int(endedAt.timeIntervalSince(startedAt)))
        let pages = SessionRules.pagesRead(start: startPage, end: endPage)
        let qualified = SessionRules.qualifies(durationSeconds: seconds, pagesRead: pages)
        let record = ReadingSessionRecord(bookID: book.bookID, bookTitle: book.title, startedAt: startedAt, startPage: startPage)
        record.endedAt = endedAt
        record.endPage = endPage
        record.durationSeconds = seconds
        record.qualified = qualified
        context.insert(record)

        book.currentPage = max(book.currentPage, endPage)
        var finished = false
        if let total = book.pageCount, endPage >= total {
            book.shelf = .read
            book.finishedAt = endedAt
            book.isCurrent = false
            book.countsTowardInky = true
            finished = true
        } else if book.shelf == .toRead {
            book.shelf = .currentlyReading
        }

        var streakDays = Store.streak(context).currentStreak
        if qualified {
            let allowFreeze = Access.allows(.streakFreeze, isPremium: isPremium)
            let streak = Store.streak(context)
            streak.state = StreakEngine.registerReading(on: endedAt, state: streak.state, allowFreeze: allowFreeze, calendar: .current)
            streakDays = streak.currentStreak
            screenTime.grantEarnedUnlock(isPremium: isPremium)
        }
        try? context.save()
        let speed = ForecastMath.pagesPerHour(pages: pages, durationSeconds: seconds)
        return SessionOutcome(
            pages: pages,
            minutes: seconds / 60,
            pagesPerHour: speed,
            qualified: qualified,
            finishedBook: finished,
            streak: streakDays
        )
    }
}

enum SnapshotSync {
    enum ReadingUpdate {
        case unchanged
        case set(ReadingSnapshot?)
    }

    @MainActor
    static func write(context: ModelContext, isPremium: Bool, reading: ReadingUpdate = .unchanged) {
        let profile = Store.profile(context)
        let streakRecord = Store.streak(context)
        let block = Store.block(context)
        let allowFreeze = Access.allows(.streakFreeze, isPremium: isPremium)
        let reconciled = StreakEngine.reconcile(state: streakRecord.state, today: Date(), allowFreeze: allowFreeze, calendar: .current)
        if reconciled != streakRecord.state {
            streakRecord.state = reconciled
        }
        let books = Store.books(context)
        let current = books.first(where: \.isCurrent) ?? books.first(where: { $0.shelf == .currentlyReading && $0.finishedAt == nil })
        let finishedCount = books.filter { $0.finishedAt != nil && $0.countsTowardInky }.count
        let samples = Store.sessions(context).compactMap { session -> (pages: Int, durationSeconds: Int)? in
            guard let end = session.endPage else { return nil }
            return (SessionRules.pagesRead(start: session.startPage, end: end), session.durationSeconds)
        }
        let speed = ForecastMath.aggregatePagesPerHour(samples: samples) ?? ForecastMath.defaultPagesPerHour
        let stage = InkyEvolution.displayedStage(finishedBooks: finishedCount, streak: reconciled.currentStreak, isPremium: isPremium)
        let mood = InkyEvolution.mood(lastReadDay: reconciled.lastQualifiedDay, now: Date(), calendar: .current)
        let pagesLeft = current.map {
            ChapterMath.pagesLeft(currentPage: $0.currentPage, totalPages: $0.pageCount, chapterLength: $0.chapterLength)
        } ?? 0
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let minutesToday = Store.sessions(context)
            .filter { ($0.endedAt ?? .distantPast) >= startOfToday }
            .reduce(0) { $0 + $1.durationSeconds } / 60

        var state = AppGroupStore.load() ?? .initial(now: Date())
        state.isPremium = isPremium
        state.pagesPerHour = speed
        state.userName = profile.name
        if case .set(let snapshot) = reading {
            state.reading = snapshot
        }
        state.shield = ShieldSnapshot(
            bookTitle: current?.title ?? "",
            pagesLeftInChapter: pagesLeft,
            stage: stage,
            mood: mood
        )
        state.widget = WidgetSnapshot(
            streak: reconciled.currentStreak,
            longestStreak: reconciled.longestStreak,
            bookTitle: current?.title,
            currentPage: current?.currentPage,
            totalPages: current?.pageCount,
            stage: stage,
            mood: mood,
            isPremium: isPremium,
            minutesToday: minutesToday
        )
        state.block = BlockSnapshot(
            schedule: block.schedule,
            unlockEndsAt: block.unlockEndsAt,
            strictMode: block.strictMode,
            unlockWindowMinutes: block.unlockWindowMinutes,
            emergencyWeekOf: block.emergencyWeekOf,
            emergencyUsesThisWeek: block.emergencyUsesThisWeek,
            isPremium: isPremium
        )
        state.updatedAt = Date()
        AppGroupStore.save(state)
        WidgetCenter.shared.reloadAllTimelines()
        try? context.save()
    }
}

enum PaceBuilder {
    @MainActor
    static func pace(context: ModelContext) -> (pace: ReadingPace, isEstimated: Bool) {
        let profile = Store.profile(context)
        let samples = Store.sessions(context).compactMap { session -> (pages: Int, durationSeconds: Int)? in
            guard let end = session.endPage else { return nil }
            return (SessionRules.pagesRead(start: session.startPage, end: end), session.durationSeconds)
        }
        let measured = ForecastMath.aggregatePagesPerHour(samples: samples)
        let durations = samples.map(\.durationSeconds)
        let typical = ForecastMath.averageSessionMinutes(durationSeconds: durations) ?? ForecastMath.defaultSessionMinutes
        let pace = ReadingPace(
            pagesPerHour: measured ?? ForecastMath.defaultPagesPerHour,
            dailyMinutes: Double(max(profile.dailyReadingGoalMinutes, 1)),
            typicalSessionMinutes: typical
        )
        return (pace, measured == nil)
    }
}
