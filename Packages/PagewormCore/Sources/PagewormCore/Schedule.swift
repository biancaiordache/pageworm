import Foundation

public struct BlockSchedule: Equatable, Codable, Sendable {
    public var enabled: Bool
    public var startHour: Int
    public var startMinute: Int
    public var endHour: Int
    public var endMinute: Int

    public init(enabled: Bool = true, startHour: Int = 9, startMinute: Int = 0, endHour: Int = 21, endMinute: Int = 0) {
        self.enabled = enabled
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }

    public static let allDay = BlockSchedule(enabled: true, startHour: 0, startMinute: 0, endHour: 23, endMinute: 59)

    public var startMinutes: Int { clampedHour(startHour) * 60 + clampedMinute(startMinute) }
    public var endMinutes: Int { clampedHour(endHour) * 60 + clampedMinute(endMinute) }

    public var intervalMinutes: Int {
        if startMinutes == endMinutes { return 24 * 60 }
        if startMinutes < endMinutes { return endMinutes - startMinutes }
        return (24 * 60 - startMinutes) + endMinutes
    }

    public var meetsDeviceActivityMinimum: Bool {
        intervalMinutes >= 15
    }

    public func contains(_ date: Date, calendar: Calendar) -> Bool {
        guard enabled else { return false }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if startMinutes == endMinutes { return true }
        if startMinutes < endMinutes {
            return minutes >= startMinutes && minutes < endMinutes
        }
        return minutes >= startMinutes || minutes < endMinutes
    }

    private func clampedHour(_ hour: Int) -> Int { min(max(hour, 0), 23) }
    private func clampedMinute(_ minute: Int) -> Int { min(max(minute, 0), 59) }
}

public enum ShieldDecision: Equatable, Sendable {
    case shield
    case clear
}

public enum ShieldPolicy {
    public static func decision(now: Date, schedule: BlockSchedule, unlockEndsAt: Date?, calendar: Calendar) -> ShieldDecision {
        let ledger = UnlockLedger(windowEndsAt: unlockEndsAt)
        if UnlockEngine.isUnlocked(now: now, ledger: ledger) { return .clear }
        return schedule.contains(now, calendar: calendar) ? .shield : .clear
    }
}
