import Foundation

public struct ShieldSnapshot: Codable, Equatable, Sendable {
    public var bookTitle: String
    public var pagesLeftInChapter: Int
    public var stage: InkyStage
    public var mood: InkyMood

    public init(bookTitle: String, pagesLeftInChapter: Int, stage: InkyStage, mood: InkyMood) {
        self.bookTitle = bookTitle
        self.pagesLeftInChapter = pagesLeftInChapter
        self.stage = stage
        self.mood = mood
    }
}

public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public var streak: Int
    public var longestStreak: Int
    public var bookTitle: String?
    public var currentPage: Int?
    public var totalPages: Int?
    public var stage: InkyStage
    public var mood: InkyMood
    public var isPremium: Bool
    public var minutesToday: Int

    public init(
        streak: Int,
        longestStreak: Int,
        bookTitle: String?,
        currentPage: Int?,
        totalPages: Int?,
        stage: InkyStage,
        mood: InkyMood,
        isPremium: Bool,
        minutesToday: Int
    ) {
        self.streak = streak
        self.longestStreak = longestStreak
        self.bookTitle = bookTitle
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.stage = stage
        self.mood = mood
        self.isPremium = isPremium
        self.minutesToday = minutesToday
    }

    public static func placeholder(isPremium: Bool) -> WidgetSnapshot {
        WidgetSnapshot(
            streak: 0,
            longestStreak: 0,
            bookTitle: nil,
            currentPage: nil,
            totalPages: nil,
            stage: .sprout,
            mood: .sleepy,
            isPremium: isPremium,
            minutesToday: 0
        )
    }
}

public struct BlockSnapshot: Codable, Equatable, Sendable {
    public var schedule: BlockSchedule
    public var unlockEndsAt: Date?
    public var strictMode: Bool
    public var unlockWindowMinutes: Int
    public var emergencyWeekOf: Date?
    public var emergencyUsesThisWeek: Int
    public var isPremium: Bool

    public init(
        schedule: BlockSchedule = BlockSchedule(),
        unlockEndsAt: Date? = nil,
        strictMode: Bool = false,
        unlockWindowMinutes: Int = UnlockPolicy.defaultWindowMinutes,
        emergencyWeekOf: Date? = nil,
        emergencyUsesThisWeek: Int = 0,
        isPremium: Bool = false
    ) {
        self.schedule = schedule
        self.unlockEndsAt = unlockEndsAt
        self.strictMode = strictMode
        self.unlockWindowMinutes = unlockWindowMinutes
        self.emergencyWeekOf = emergencyWeekOf
        self.emergencyUsesThisWeek = emergencyUsesThisWeek
        self.isPremium = isPremium
    }
}

public struct ReadingSnapshot: Codable, Equatable, Sendable {
    public var bookID: UUID
    public var bookTitle: String
    public var startPage: Int
    public var startedAt: Date

    public init(bookID: UUID, bookTitle: String, startPage: Int, startedAt: Date) {
        self.bookID = bookID
        self.bookTitle = bookTitle
        self.startPage = startPage
        self.startedAt = startedAt
    }
}

public struct SharedAppState: Codable, Equatable, Sendable {
    public var updatedAt: Date
    public var isPremium: Bool
    public var pagesPerHour: Double
    public var userName: String
    public var shield: ShieldSnapshot
    public var widget: WidgetSnapshot
    public var block: BlockSnapshot
    public var reading: ReadingSnapshot?

    public init(
        updatedAt: Date,
        isPremium: Bool,
        pagesPerHour: Double,
        userName: String,
        shield: ShieldSnapshot,
        widget: WidgetSnapshot,
        block: BlockSnapshot,
        reading: ReadingSnapshot?
    ) {
        self.updatedAt = updatedAt
        self.isPremium = isPremium
        self.pagesPerHour = pagesPerHour
        self.userName = userName
        self.shield = shield
        self.widget = widget
        self.block = block
        self.reading = reading
    }

    public static func initial(now: Date) -> SharedAppState {
        let shield = ShieldSnapshot(bookTitle: "", pagesLeftInChapter: 0, stage: .sprout, mood: .sleepy)
        return SharedAppState(
            updatedAt: now,
            isPremium: false,
            pagesPerHour: ForecastMath.defaultPagesPerHour,
            userName: "",
            shield: shield,
            widget: .placeholder(isPremium: false),
            block: BlockSnapshot(),
            reading: nil
        )
    }
}

public enum SnapshotCoding {
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    public static func encode(_ state: SharedAppState) throws -> Data {
        try encoder().encode(state)
    }

    public static func decode(_ data: Data) throws -> SharedAppState {
        try decoder().decode(SharedAppState.self, from: data)
    }
}
