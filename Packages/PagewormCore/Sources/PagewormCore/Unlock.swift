import Foundation

public struct UnlockPolicy: Equatable, Codable, Sendable {
    public var windowMinutes: Int
    public var strictMode: Bool

    public static let minimumWindowMinutes = 15
    public static let defaultWindowMinutes = 15
    public static let emergencyUnlocksPerWeek = 1
    public static let choices = [15, 30, 45, 60]

    public init(windowMinutes: Int = defaultWindowMinutes, strictMode: Bool = false) {
        self.windowMinutes = windowMinutes
        self.strictMode = strictMode
    }

    /// Device Activity schedules cannot be shorter than 15 minutes.
    public var effectiveWindowMinutes: Int {
        max(windowMinutes, Self.minimumWindowMinutes)
    }
}

public struct UnlockLedger: Equatable, Codable, Sendable {
    public var windowEndsAt: Date?
    public var emergencyWeekOf: Date?
    public var emergencyUsesThisWeek: Int
    public var lastEmergencyAt: Date?

    public init(
        windowEndsAt: Date? = nil,
        emergencyWeekOf: Date? = nil,
        emergencyUsesThisWeek: Int = 0,
        lastEmergencyAt: Date? = nil
    ) {
        self.windowEndsAt = windowEndsAt
        self.emergencyWeekOf = emergencyWeekOf
        self.emergencyUsesThisWeek = emergencyUsesThisWeek
        self.lastEmergencyAt = lastEmergencyAt
    }
}

public enum UnlockError: Error, Equatable, Sendable {
    case strictModeRequired
    case weeklyLimitReached
}

public enum UnlockEngine {
    public static func isUnlocked(now: Date, ledger: UnlockLedger) -> Bool {
        guard let end = ledger.windowEndsAt else { return false }
        return now < end
    }

    public static func grantEarned(now: Date, policy: UnlockPolicy, ledger: UnlockLedger) -> UnlockLedger {
        var ledger = ledger
        ledger.windowEndsAt = now.addingTimeInterval(TimeInterval(policy.effectiveWindowMinutes * 60))
        return ledger
    }

    public static func snapBack(now: Date, ledger: UnlockLedger) -> UnlockLedger {
        guard let end = ledger.windowEndsAt, now >= end else { return ledger }
        var ledger = ledger
        ledger.windowEndsAt = nil
        return ledger
    }

    public static func normalizeWeek(now: Date, ledger: UnlockLedger, calendar: Calendar) -> UnlockLedger {
        var ledger = ledger
        let week = StreakEngine.weekStart(now, calendar: calendar)
        let stored = ledger.emergencyWeekOf.map { StreakEngine.startOfDay($0, calendar: calendar) }
        if stored != week {
            ledger.emergencyWeekOf = week
            ledger.emergencyUsesThisWeek = 0
        }
        return ledger
    }

    public static func emergencyRemaining(now: Date, policy: UnlockPolicy, ledger: UnlockLedger, calendar: Calendar) -> Int {
        guard policy.strictMode else { return 0 }
        let ledger = normalizeWeek(now: now, ledger: ledger, calendar: calendar)
        return max(0, UnlockPolicy.emergencyUnlocksPerWeek - ledger.emergencyUsesThisWeek)
    }

    public static func redeemEmergency(
        now: Date,
        policy: UnlockPolicy,
        ledger: UnlockLedger,
        calendar: Calendar
    ) -> Result<UnlockLedger, UnlockError> {
        guard policy.strictMode else { return .failure(.strictModeRequired) }
        var ledger = normalizeWeek(now: now, ledger: ledger, calendar: calendar)
        guard ledger.emergencyUsesThisWeek < UnlockPolicy.emergencyUnlocksPerWeek else {
            return .failure(.weeklyLimitReached)
        }
        ledger.emergencyUsesThisWeek += 1
        ledger.lastEmergencyAt = now
        ledger.emergencyWeekOf = StreakEngine.weekStart(now, calendar: calendar)
        return .success(grantEarned(now: now, policy: policy, ledger: ledger))
    }
}
