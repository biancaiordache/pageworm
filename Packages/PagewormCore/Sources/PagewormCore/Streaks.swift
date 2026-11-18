import Foundation

public struct StreakEvaluation: Equatable {
    public var currentStreak: Int
    public var frozenDays: [Date]
    public var readToday: Bool
    public var atRisk: Bool
    public var freezeUsedThisWeek: Bool

    public init(
        currentStreak: Int,
        frozenDays: [Date],
        readToday: Bool,
        atRisk: Bool,
        freezeUsedThisWeek: Bool
    ) {
        self.currentStreak = currentStreak
        self.frozenDays = frozenDays
        self.readToday = readToday
        self.atRisk = atRisk
        self.freezeUsedThisWeek = freezeUsedThisWeek
    }
}

public enum StreakCalculator {
    /// Walks backward from today. Today never burns a freeze. One missed day per week can bridge the streak when `allowsFreeze` is true. Frozen days do not increment the count.
    public static func evaluate(
        readingDays: Set<Date>,
        today: Date,
        calendar: Calendar,
        allowsFreeze: Bool
    ) -> StreakEvaluation {
        let days = Set(readingDays.map { calendar.startOfDay(for: $0) })
        let todayStart = calendar.startOfDay(for: today)
        let readToday = days.contains(todayStart)
        guard let oldest = days.min() else {
            return StreakEvaluation(
                currentStreak: 0,
                frozenDays: [],
                readToday: false,
                atRisk: false,
                freezeUsedThisWeek: false
            )
        }

        var cursor = todayStart
        if !readToday {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) else {
                return empty(readToday: false)
            }
            cursor = yesterday
        }

        var streak = 0
        var frozen: [Date] = []
        var usedWeeks: Set<String> = []

        for _ in 0..<4000 {
            if days.contains(cursor) {
                streak += 1
            } else if allowsFreeze, cursor > oldest, !usedWeeks.contains(EmergencyUnlockPolicy.weekID(cursor, calendar: calendar)) {
                usedWeeks.insert(EmergencyUnlockPolicy.weekID(cursor, calendar: calendar))
                frozen.append(cursor)
            } else {
                break
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        if streak == 0 {
            frozen = []
        }
        let thisWeek = EmergencyUnlockPolicy.weekID(todayStart, calendar: calendar)
        let usedThisWeek = frozen.contains { EmergencyUnlockPolicy.weekID($0, calendar: calendar) == thisWeek }
        return StreakEvaluation(
            currentStreak: streak,
            frozenDays: frozen,
            readToday: readToday,
            atRisk: !readToday && streak > 0,
            freezeUsedThisWeek: usedThisWeek
        )
    }

    private static func empty(readToday: Bool) -> StreakEvaluation {
        StreakEvaluation(
            currentStreak: 0,
            frozenDays: [],
            readToday: readToday,
            atRisk: false,
            freezeUsedThisWeek: false
        )
    }
}
