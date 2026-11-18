import Foundation
import PagewormCore
import UserNotifications

extension Notification.Name {
    static let pagewormShieldWantsRead = Notification.Name("pagewormShieldWantsRead")
}

@MainActor
final class InkyNotifications: NSObject, UNUserNotificationCenterDelegate {
    var onOpenRead: (() -> Void)?

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .pagewormShieldWantsRead, object: nil)
                }
            },
            SharedKeys.openReadNotification as CFString,
            nil,
            .deliverImmediately
        )
    }

    func request() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func reschedule(name: String, notificationsEnabled: Bool, readToday: Bool, missing: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["pageworm.streak", "pageworm.miss"])
        guard notificationsEnabled else { return }
        if !readToday {
            let content = UNMutableNotificationContent()
            content.title = "Inky"
            content.body = "\(name.isEmpty ? "Hey" : name), the streak is pacing by the door. A few pages will sit it down."
            content.sound = .default
            var when = DateComponents()
            when.hour = 20
            center.add(UNNotificationRequest(
                identifier: "pageworm.streak",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
            ))
        }
        if missing {
            let content = UNMutableNotificationContent()
            content.title = "Inky"
            content.body = "I missed you. The bookmark hasn't moved."
            content.sound = .default
            center.add(UNNotificationRequest(
                identifier: "pageworm.miss",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60, repeats: false)
            ))
        }
    }

    func scheduleUnlockEnding(at date: Date) {
        let interval = date.timeIntervalSinceNow - 60
        guard interval > 5 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Inky"
        content.body = "The door is closing."
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: "pageworm.unlock",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        ))
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        onOpenRead?()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
