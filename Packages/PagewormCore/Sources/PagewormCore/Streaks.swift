import Foundation

public struct StreakState: Equatable, Codable, Sendable {
    public var currentStreak: Int
    public var longestStreak: Int
    public var lastQualifiedDay: Date?
    /// Start of the week in which the weekly freeze was spent.
    public var freezeUsedWeekOf: Date?
    /// The missed day the freeze stood in for.
    public var lastFreezeCoveredDay: Date?

    public init(
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastQualifiedDay: Date? = nil,
        freezeUsedWeekOf: Date? = nil,
        lastFreezeCoveredDay: Date? = nil
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastQualifiedDay = lastQualifiedDay
        self.freezeUsedWeekOf = freezeUsedWeekOf
        self.lastFreezeCoveredDay = lastFreezeCoveredDay
    }
}

public enum StreakHealth: Equatable, Sendable {
    case empty
    case active(days: Int)
    case atRisk(days: Int)
    case savedByFreeze(days: Int)
    case broken
}

public enum StreakEngine {
    public static func startOfDay(_ date: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: date)
    }

    public static func weekStart(_ date: Date, calendar: Calendar) -> Date? {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return nil }
        return calendar.startOfDay(for: start)
    }

    public static func freezeAvailable(state: StreakState, today: Date, allowFreeze: Bool, calendar: Calendar) -> Bool {
        guard allowFreeze, let week = weekStart(today, calendar: calendar) else { return false }
        guard let used = state.freezeUsedWeekOf else { return true }
        return startOfDay(used, calendar: calendar) != startOfDay(week, calendar: calendar)
    }

    /// Closes yesterday with a freeze when exactly one day was missed, or marks the streak broken.
    public static func reconcile(state: StreakState, today: Date, allowFreeze: Bool, calendar: Calendar) -> StreakState {
        guard let last = state.lastQualifiedDay else { return state }
        var state = state
        let today = startOfDay(today, calendar: calendar)
        let lastDay = startOfDay(last, calendar: calendar)
        state.lastQualifiedDay = lastDay
        guard lastDay < today else { return state }
        let gap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        if gap <= 1 { return state }
        if gap == 2, let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
            let missed = startOfDay(yesterday, calendar: calendar)
            if freezeAvailable(state: state, today: missed, allowFreeze: allowFreeze, calendar: calendar) {
                state.lastQualifiedDay = missed
                state.freezeUsedWeekOf = weekStart(missed, calendar: calendar)
                state.lastFreezeCoveredDay = missed
                return state
            }
        }
        state.currentStreak = 0
        return state
    }

    public static func registerReading(on day: Date, state: StreakState, allowFreeze: Bool, calendar: Calendar) -> StreakState {
        var state = reconcile(state: state, today: day, allowFreeze: allowFreeze, calendar: calendar)
        let day = startOfDay(day, calendar: calendar)
        if let last = state.lastQualifiedDay.map({ startOfDay($0, calendar: calendar) }) {
            if last == day { return state }
            let yesterday = calendar.date(byAdding: .day, value: -1, to: day).map { startOfDay($0, calendar: calendar) }
            if state.currentStreak > 0, yesterday == last {
                state.currentStreak += 1
            } else {
                state.currentStreak = 1
            }
        } else {
            state.currentStreak = 1
        }
        state.longestStreak = max(state.longestStreak, state.currentStreak)
        state.lastQualifiedDay = day
        return state
    }

    public static func health(state: StreakState, today: Date, allowFreeze: Bool, calendar: Calendar) -> StreakHealth {
        let state = reconcile(state: state, today: today, allowFreeze: allowFreeze, calendar: calendar)
        guard state.currentStreak > 0, let last = state.lastQualifiedDay else {
            if state.longestStreak == 0 && state.lastQualifiedDay == nil { return .empty }
            return .broken
        }
        let today = startOfDay(today, calendar: calendar)
        let lastDay = startOfDay(last, calendar: calendar)
        if lastDay == today { return .active(days: state.currentStreak) }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           startOfDay(yesterday, calendar: calendar) == lastDay {
            if let covered = state.lastFreezeCoveredDay,
               startOfDay(covered, calendar: calendar) == lastDay {
                return .savedByFreeze(days: state.currentStreak)
            }
            return .atRisk(days: state.currentStreak)
        }
        return .broken
    }
}
