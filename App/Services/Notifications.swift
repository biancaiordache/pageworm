import Foundation
import UserNotifications

enum InkyNotifications {
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func scheduleDaily(name: String, atRisk: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["pageworm.daily"])
        var components = DateComponents()
        components.hour = 20
        components.minute = 0
        let content = UNMutableNotificationContent()
        content.title = "Inky"
        let who = name.trimmingCharacters(in: .whitespacesAndNewlines)
        content.body = atRisk
            ? "Your streak is getting sleepy. One chapter keeps it warm."
            : "The bookmark is still in the page. Ten minutes\(who.isEmpty ? "" : ", \(who)")?"
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: "pageworm.daily", content: content, trigger: trigger))
    }

    static func scheduleUnlockEnding(at date: Date?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["pageworm.unlock-end"])
        guard let date else { return }
        let interval = date.timeIntervalSinceNow
        guard interval > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Inky"
        content.body = "Break's over. I'm back on the book."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: "pageworm.unlock-end", content: content, trigger: trigger))
    }

    static func scheduleTrialReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Inky"
        content.body = "Tomorrow the trial becomes a library card. I'll still be here either way."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 6 * 24 * 60 * 60, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "pageworm.trial-day6", content: content, trigger: trigger)
        )
    }

    static func scheduleShieldNudge() {
        let content = UNMutableNotificationContent()
        content.title = "Inky"
        content.body = "Open me and start reading. I'll move when the chapter moves."
        content.sound = .default
        content.userInfo = ["link": "pageworm://read"]
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
