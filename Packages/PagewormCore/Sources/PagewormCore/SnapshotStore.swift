import Foundation

public struct ActiveSessionState: Codable, Equatable {
    public var bookID: String
    public var bookTitle: String
    public var startPage: Int
    public var startedAt: Date

    public init(bookID: String, bookTitle: String, startPage: Int, startedAt: Date) {
        self.bookID = bookID
        self.bookTitle = bookTitle
        self.startPage = startPage
        self.startedAt = startedAt
    }
}

public struct ShieldSnapshot: Codable, Equatable {
    public var bookTitle: String
    public var pagesToNextChapter: Int
    public var focusAppName: String
    public var inkyStage: InkyStage
    public var inkyMood: InkyMood
    public var streak: Int
    public var isPremium: Bool
    public var pagesPerHour: Double
    public var blockingEnabled: Bool
    public var strictMode: Bool
    public var unlock: UnlockWindow?
    public var schedule: BlockSchedule
    public var updatedAt: Date

    public init(
        bookTitle: String,
        pagesToNextChapter: Int,
        focusAppName: String,
        inkyStage: InkyStage,
        inkyMood: InkyMood,
        streak: Int,
        isPremium: Bool,
        pagesPerHour: Double,
        blockingEnabled: Bool,
        strictMode: Bool,
        unlock: UnlockWindow?,
        schedule: BlockSchedule,
        updatedAt: Date
    ) {
        self.bookTitle = bookTitle
        self.pagesToNextChapter = pagesToNextChapter
        self.focusAppName = focusAppName
        self.inkyStage = inkyStage
        self.inkyMood = inkyMood
        self.streak = streak
        self.isPremium = isPremium
        self.pagesPerHour = pagesPerHour
        self.blockingEnabled = blockingEnabled
        self.strictMode = strictMode
        self.unlock = unlock
        self.schedule = schedule
        self.updatedAt = updatedAt
    }

    public static func placeholder(now: Date = Date()) -> ShieldSnapshot {
        ShieldSnapshot(
            bookTitle: "",
            pagesToNextChapter: 0,
            focusAppName: "",
            inkyStage: .bookling,
            inkyMood: .happy,
            streak: 0,
            isPremium: false,
            pagesPerHour: ReadingStats.defaultPagesPerHour,
            blockingEnabled: false,
            strictMode: false,
            unlock: nil,
            schedule: .allDay,
            updatedAt: now
        )
    }
}

public enum SnapshotCoding {
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public enum SharedStore {
    public static func snapshot(in defaults: UserDefaults) -> ShieldSnapshot {
        guard let data = defaults.data(forKey: SharedKeys.snapshot),
              let snapshot = try? SnapshotCoding.decoder().decode(ShieldSnapshot.self, from: data)
        else {
            return .placeholder()
        }
        return snapshot
    }

    public static func setSnapshot(_ snapshot: ShieldSnapshot, in defaults: UserDefaults) {
        if let data = try? SnapshotCoding.encoder().encode(snapshot) {
            defaults.set(data, forKey: SharedKeys.snapshot)
        }
    }

    public static func selectionData(in defaults: UserDefaults) -> Data? {
        defaults.data(forKey: SharedKeys.selection)
    }

    public static func setSelectionData(_ data: Data?, in defaults: UserDefaults) {
        if let data {
            defaults.set(data, forKey: SharedKeys.selection)
        } else {
            defaults.removeObject(forKey: SharedKeys.selection)
        }
    }

    public static func activeSession(in defaults: UserDefaults) -> ActiveSessionState? {
        guard let data = defaults.data(forKey: SharedKeys.activeSession) else { return nil }
        return try? SnapshotCoding.decoder().decode(ActiveSessionState.self, from: data)
    }

    public static func setActiveSession(_ session: ActiveSessionState?, in defaults: UserDefaults) {
        if let session, let data = try? SnapshotCoding.encoder().encode(session) {
            defaults.set(data, forKey: SharedKeys.activeSession)
        } else {
            defaults.removeObject(forKey: SharedKeys.activeSession)
        }
    }

    public static func setPendingRead(_ pending: Bool, in defaults: UserDefaults) {
        defaults.set(pending, forKey: SharedKeys.pendingReadLaunch)
    }

    public static func consumePendingRead(in defaults: UserDefaults) -> Bool {
        let pending = defaults.bool(forKey: SharedKeys.pendingReadLaunch)
        if pending {
            defaults.set(false, forKey: SharedKeys.pendingReadLaunch)
        }
        return pending
    }
}
