import ManagedSettings
import PagewormDesign
import UserNotifications

/// Shields cannot open the host app. The button closes the blocked app,
/// remembers that Inky asked for a reading session, and posts a notification
/// that deep-links back into Pageworm.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler: completionHandler)
    }

    private func respond(_ action: ShieldAction, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            AppGroupStore.setPendingRead(true)
            InkyNotificationsBridge.nudge()
            completionHandler(.close)
        default:
            completionHandler(.close)
        }
    }
}

enum InkyNotificationsBridge {
    static func nudge() {
        let content = UNMutableNotificationContent()
        content.title = "Inky"
        content.body = "Open me and start reading. I'll move when the chapter moves."
        content.sound = .default
        content.userInfo = ["link": "pageworm://read"]
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
