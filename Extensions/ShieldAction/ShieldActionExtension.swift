import Foundation
import ManagedSettings
import PagewormCore

/// iOS does not let a shield extension bring the host app forward.
/// Start reading records a pending launch. If Pageworm is already running it hears a Darwin notification;
/// otherwise the next time the app opens it lands on the timer.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler: completionHandler)
    }

    private func respond(to action: ShieldAction, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        if case .primaryButtonPressed = action {
            let defaults = AppGroupDefaults.suite()
            SharedStore.setPendingRead(true, in: defaults)
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName(SharedKeys.openReadNotification as CFString),
                nil,
                nil,
                true
            )
        }
        completionHandler(.close)
    }
}
