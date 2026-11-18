import Foundation

public enum UnlockSource: String, Codable, Equatable {
    case readingSession
    case emergency
}

public struct UnlockWindow: Codable, Equatable {
    public var startsAt: Date
    public var endsAt: Date
    public var source: UnlockSource

    public init(startsAt: Date, endsAt: Date, source: UnlockSource) {
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.source = source
    }

    public func contains(_ date: Date) -> Bool {
        date >= startsAt && date < endsAt
    }

    public func remaining(at date: Date) -> TimeInterval {
        max(0, endsAt.timeIntervalSince(date))
    }
}

public enum UnlockPolicy {
    /// Device Activity refuses schedules shorter than 15 minutes.
    public static let minimumMinutes = 15
    public static let defaultMinutes = 15
    public static let allowedMinutes = [15, 30, 45, 60]
    public static let minimumSessionSeconds: TimeInterval = 60

    public static func normalizedMinutes(_ minutes: Int) -> Int {
        allowedMinutes.min(by: { abs($0 - minutes) < abs($1 - minutes) }) ?? defaultMinutes
    }

    public static func grantsUnlock(elapsed: TimeInterval) -> Bool {
        elapsed >= minimumSessionSeconds
    }

    public static func makeWindow(from start: Date, minutes: Int, source: UnlockSource) -> UnlockWindow {
        let length = normalizedMinutes(minutes)
        return UnlockWindow(
            startsAt: start,
            endsAt: start.addingTimeInterval(TimeInterval(length * 60)),
            source: source
        )
    }
}

public enum EmergencyUnlockPolicy {
    public static func canRedeem(lastRedeemedAt: Date?, now: Date, calendar: Calendar) -> Bool {
        guard let lastRedeemedAt else { return true }
        return weekID(lastRedeemedAt, calendar: calendar) != weekID(now, calendar: calendar)
    }

    public static func weekID(_ date: Date, calendar: Calendar) -> String {
        let week = calendar.component(.weekOfYear, from: date)
        let year = calendar.component(.yearForWeekOfYear, from: date)
        return "\(year)-\(week)"
    }
}

public struct BlockSchedule: Codable, Equatable {
    public var enabled: Bool
    /// Minutes from local midnight. End is exclusive and may be 1440 for the following midnight.
    public var startMinutes: Int
    public var endMinutes: Int
    /// Gregorian weekday: 1 is Sunday … 7 is Saturday.
    public var weekdays: Set<Int>

    public init(enabled: Bool, startMinutes: Int, endMinutes: Int, weekdays: Set<Int>) {
        self.enabled = enabled
        self.startMinutes = min(max(startMinutes, 0), 24 * 60)
        self.endMinutes = min(max(endMinutes, 0), 24 * 60)
        self.weekdays = weekdays
    }

    public static let allDay = BlockSchedule(
        enabled: true,
        startMinutes: 0,
        endMinutes: 24 * 60,
        weekdays: Set(1...7)
    )

    public static let mornings = BlockSchedule(
        enabled: true,
        startMinutes: 7 * 60,
        endMinutes: 12 * 60,
        weekdays: Set(1...7)
    )

    public static let workday = BlockSchedule(
        enabled: true,
        startMinutes: 9 * 60,
        endMinutes: 17 * 60,
        weekdays: Set([2, 3, 4, 5, 6])
    )

    public static let evenings = BlockSchedule(
        enabled: true,
        startMinutes: 18 * 60,
        endMinutes: 23 * 60,
        weekdays: Set(1...7)
    )

    public var crossesMidnight: Bool {
        enabled && endMinutes < startMinutes
    }

    public func contains(_ date: Date, calendar: Calendar) -> Bool {
        guard enabled, !weekdays.isEmpty else { return false }
        guard startMinutes != endMinutes else { return false }
        let parts = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let weekday = parts.weekday ?? 1

        if startMinutes < endMinutes {
            return weekdays.contains(weekday) && minutes >= startMinutes && minutes < endMinutes
        }
        if minutes >= startMinutes {
            return weekdays.contains(weekday)
        }
        if minutes < endMinutes {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date) else { return false }
            return weekdays.contains(calendar.component(.weekday, from: yesterday))
        }
        return false
    }
}

public enum ShieldDecision: Equatable {
    case inactive
    case blocked
    case unlocked(until: Date)
}

public enum ShieldBrain {
    public static func decide(
        now: Date,
        blockingEnabled: Bool,
        schedule: BlockSchedule,
        unlock: UnlockWindow?,
        calendar: Calendar
    ) -> ShieldDecision {
        guard blockingEnabled else { return .inactive }
        if let unlock, unlock.contains(now) {
            return .unlocked(until: unlock.endsAt)
        }
        if schedule.contains(now, calendar: calendar) {
            return .blocked
        }
        return .inactive
    }
}
