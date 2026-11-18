import DeviceActivity
import Foundation
import PagewormCore

enum ScheduleMonitor {
    private static let signatureKey = "pageworm.monitorSignature"

    static func sync(schedule: BlockSchedule, unlock: UnlockWindow?) {
        let days = schedule.weekdays.sorted().map(String.init).joined(separator: ",")
        let signature = "\(schedule.enabled)|\(schedule.startMinutes)|\(schedule.endMinutes)|\(days)|\(unlock?.endsAt.timeIntervalSince1970 ?? 0)"
        let defaults = AppGroupDefaults.suite()
        if defaults.string(forKey: signatureKey) == signature { return }

        let center = DeviceActivityCenter()
        let block = DeviceActivityName(SharedKeys.blockingActivityName)
        let unlockName = DeviceActivityName(SharedKeys.unlockActivityName)
        center.stopMonitoring([block, unlockName])

        do {
            if schedule.enabled {
                let endMinutes = min(max(schedule.endMinutes, 0), 24 * 60)
                let end = endMinutes >= 24 * 60
                    ? DateComponents(hour: 23, minute: 59)
                    : DateComponents(hour: endMinutes / 60, minute: endMinutes % 60)
                let start = DateComponents(hour: schedule.startMinutes / 60, minute: schedule.startMinutes % 60)
                let activity = DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: true)
                try center.startMonitoring(block, during: activity)
            }
            if let unlock {
                let calendar = PagewormCalendar.make()
                let start = calendar.dateComponents([.hour, .minute], from: unlock.startsAt)
                var end = calendar.dateComponents([.hour, .minute], from: unlock.endsAt)
                if start.hour == end.hour && start.minute == end.minute {
                    end.minute = ((end.minute ?? 0) + UnlockPolicy.minimumMinutes) % 60
                }
                let activity = DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: false)
                try center.startMonitoring(unlockName, during: activity)
            }
            defaults.set(signature, forKey: signatureKey)
        } catch {
            defaults.removeObject(forKey: signatureKey)
        }
    }
}
