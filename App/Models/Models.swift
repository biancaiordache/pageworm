import Foundation
import SwiftData
import PagewormCore

@Model
final class UserProfile {
    var name: String = ""
    var whyHere: String = ""
    var dailyPhoneHours: Double = 4
    var distractingApps: [String] = []
    var dailyReadingGoalMinutes: Int = 30
    var onboardingStep: Int = 0
    var onboardingCompleted: Bool = false
    var pledgeSignedAt: Date?
    var createdAt: Date = Date()
    var notificationsAllowed: Bool = false

    init() {}
}

@Model
final class Book {
    var bookID: UUID = UUID()
    var title: String = ""
    var authors: String = ""
    var isbn: String?
    var pageCount: Int?
    var currentPage: Int = 0
    var shelfRaw: String = ReadingShelf.toRead.rawValue
    var coverURL: String?
    var sourceRaw: String = LibrarySource.manual.rawValue
    var dateAdded: Date = Date()
    var finishedAt: Date?
    var isCurrent: Bool = false
    var chapterLength: Int = ChapterMath.defaultLength
    /// Imported history does not age Inky. Books finished inside Pageworm do.
    var countsTowardInky: Bool = true

    init(
        title: String,
        authors: String,
        isbn: String? = nil,
        pageCount: Int? = nil,
        currentPage: Int = 0,
        shelf: ReadingShelf = .toRead,
        coverURL: String? = nil,
        source: LibrarySource = .manual,
        dateAdded: Date = Date(),
        finishedAt: Date? = nil,
        isCurrent: Bool = false,
        countsTowardInky: Bool = true
    ) {
        self.bookID = UUID()
        self.title = title
        self.authors = authors
        self.isbn = isbn
        self.pageCount = pageCount
        self.currentPage = currentPage
        self.shelfRaw = shelf.rawValue
        self.coverURL = coverURL
        self.sourceRaw = source.rawValue
        self.dateAdded = dateAdded
        self.finishedAt = finishedAt
        self.isCurrent = isCurrent
        self.chapterLength = ChapterMath.defaultLength
        self.countsTowardInky = countsTowardInky
    }

    var shelf: ReadingShelf {
        get { ReadingShelf(rawValue: shelfRaw) ?? .other }
        set { shelfRaw = newValue.rawValue }
    }

    var source: LibrarySource {
        get { LibrarySource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var remainingPages: Int? {
        ForecastMath.remainingPages(currentPage: currentPage, totalPages: pageCount)
    }
}

@Model
final class ReadingSessionRecord {
    var sessionID: UUID = UUID()
    var bookID: UUID = UUID()
    var bookTitle: String = ""
    var startedAt: Date = Date()
    var endedAt: Date?
    var startPage: Int = 0
    var endPage: Int?
    var durationSeconds: Int = 0
    var qualified: Bool = false

    init(bookID: UUID, bookTitle: String, startedAt: Date, startPage: Int) {
        self.sessionID = UUID()
        self.bookID = bookID
        self.bookTitle = bookTitle
        self.startedAt = startedAt
        self.startPage = startPage
    }
}

@Model
final class StreakRecord {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastQualifiedDay: Date?
    var freezeUsedWeekOf: Date?
    var lastFreezeCoveredDay: Date?
    var updatedAt: Date = Date()

    init() {}

    var state: StreakState {
        get {
            StreakState(
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                lastQualifiedDay: lastQualifiedDay,
                freezeUsedWeekOf: freezeUsedWeekOf,
                lastFreezeCoveredDay: lastFreezeCoveredDay
            )
        }
        set {
            currentStreak = newValue.currentStreak
            longestStreak = newValue.longestStreak
            lastQualifiedDay = newValue.lastQualifiedDay
            freezeUsedWeekOf = newValue.freezeUsedWeekOf
            lastFreezeCoveredDay = newValue.lastFreezeCoveredDay
            updatedAt = Date()
        }
    }
}

@Model
final class BlockRecord {
    var scheduleEnabled: Bool = true
    var startHour: Int = 9
    var startMinute: Int = 0
    var endHour: Int = 21
    var endMinute: Int = 0
    var unlockWindowMinutes: Int = UnlockPolicy.defaultWindowMinutes
    var strictMode: Bool = false
    var unlockEndsAt: Date?
    var emergencyWeekOf: Date?
    var emergencyUsesThisWeek: Int = 0
    var updatedAt: Date = Date()

    init() {}

    var schedule: BlockSchedule {
        get {
            BlockSchedule(
                enabled: scheduleEnabled,
                startHour: startHour,
                startMinute: startMinute,
                endHour: endHour,
                endMinute: endMinute
            )
        }
        set {
            scheduleEnabled = newValue.enabled
            startHour = newValue.startHour
            startMinute = newValue.startMinute
            endHour = newValue.endHour
            endMinute = newValue.endMinute
            updatedAt = Date()
        }
    }
}

enum Store {
    @MainActor
    static func profile(_ context: ModelContext) -> UserProfile {
        fetchOrMake(context, make: UserProfile.init)
    }

    @MainActor
    static func streak(_ context: ModelContext) -> StreakRecord {
        fetchOrMake(context, make: StreakRecord.init)
    }

    @MainActor
    static func block(_ context: ModelContext) -> BlockRecord {
        fetchOrMake(context, make: BlockRecord.init)
    }

    @MainActor
    static func books(_ context: ModelContext) -> [Book] {
        (try? context.fetch(FetchDescriptor<Book>())) ?? []
    }

    @MainActor
    static func sessions(_ context: ModelContext) -> [ReadingSessionRecord] {
        (try? context.fetch(FetchDescriptor<ReadingSessionRecord>())) ?? []
    }

    @MainActor
    static func currentBook(_ context: ModelContext) -> Book? {
        let books = books(context)
        return books.first(where: \.isCurrent) ?? books.first(where: { $0.shelf == .currentlyReading })
    }

    @MainActor
    private static func fetchOrMake<T: PersistentModel>(_ context: ModelContext, make: () -> T) -> T {
        var descriptor = FetchDescriptor<T>()
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = make()
        context.insert(created)
        return created
    }
}
