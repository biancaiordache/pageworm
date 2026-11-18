import Foundation
import SwiftData
import PagewormCore

@Model
final class UserProfile {
    var name: String
    var whyHere: String
    var dailyPhoneHours: Double
    var distractingApps: [String]
    var dailyReadingMinutes: Int
    var age: Int
    var onboardingComplete: Bool
    var pledgeSignedAt: Date?
    var isPremium: Bool
    var strictMode: Bool
    var unlockMinutes: Int
    var pagesPerChapter: Int
    var createdAt: Date
    var lastEmergencyUnlockAt: Date?
    var notificationsEnabled: Bool
    var blockingEnabled: Bool
    var blockStartMinutes: Int
    var blockEndMinutes: Int
    var blockWeekdays: [Int]

    init() {
        name = ""
        whyHere = ""
        dailyPhoneHours = 4
        distractingApps = []
        dailyReadingMinutes = 20
        age = AttentionMath.defaultAge
        onboardingComplete = false
        pledgeSignedAt = nil
        isPremium = false
        strictMode = false
        unlockMinutes = UnlockPolicy.defaultMinutes
        pagesPerChapter = 15
        createdAt = Date()
        lastEmergencyUnlockAt = nil
        notificationsEnabled = false
        blockingEnabled = false
        blockStartMinutes = 0
        blockEndMinutes = 24 * 60
        blockWeekdays = Array(1...7)
    }

    var schedule: BlockSchedule {
        get {
            BlockSchedule(
                enabled: blockingEnabled,
                startMinutes: blockStartMinutes,
                endMinutes: blockEndMinutes,
                weekdays: Set(blockWeekdays)
            )
        }
        set {
            blockingEnabled = newValue.enabled
            blockStartMinutes = newValue.startMinutes
            blockEndMinutes = newValue.endMinutes
            blockWeekdays = newValue.weekdays.sorted()
        }
    }
}

@Model
final class Book {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    var isbn: String?
    var pageCount: Int?
    var currentPage: Int
    var shelfRaw: String
    var coverURL: String?
    var sourceRaw: String
    var dateAdded: Date
    var finishedAt: Date?
    var isCurrent: Bool
    var rating: Double?

    init(
        title: String,
        author: String,
        isbn: String? = nil,
        pageCount: Int? = nil,
        currentPage: Int = 0,
        shelf: ReadingShelf = .toRead,
        coverURL: String? = nil,
        source: String = "manual",
        dateAdded: Date = Date(),
        rating: Double? = nil
    ) {
        id = UUID()
        self.title = title
        self.author = author
        self.isbn = isbn
        self.pageCount = pageCount
        self.currentPage = currentPage
        shelfRaw = shelf.rawValue
        self.coverURL = coverURL
        sourceRaw = source
        self.dateAdded = dateAdded
        finishedAt = nil
        isCurrent = shelf == .currentlyReading
        self.rating = rating
    }

    var shelf: ReadingShelf {
        get { ReadingShelf(rawValue: shelfRaw) ?? .other }
        set { shelfRaw = newValue.rawValue }
    }
}

@Model
final class ReadingSessionRecord {
    var id: UUID
    var bookID: UUID
    var bookTitle: String
    var startedAt: Date
    var endedAt: Date
    var startPage: Int
    var endPage: Int
    var pages: Int
    var minutes: Double

    init(
        bookID: UUID,
        bookTitle: String,
        startedAt: Date,
        endedAt: Date,
        startPage: Int,
        endPage: Int,
        pages: Int,
        minutes: Double
    ) {
        id = UUID()
        self.bookID = bookID
        self.bookTitle = bookTitle
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.startPage = startPage
        self.endPage = endPage
        self.pages = pages
        self.minutes = minutes
    }
}
