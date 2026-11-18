import Foundation

/// Identifiers shared by the app and its extensions.
/// The App Group string must match the entitlements exactly.
public enum SharedKeys {
    public static let appGroupID = "group.com.pageworm.shared"
    public static let managedSettingsStoreName = "pageworm"
    public static let blockingActivityName = "pageworm.scheduledBlock"
    public static let unlockActivityName = "pageworm.unlockWindow"
    public static let reportContext = "pageworm.weeklyScroll"

    public static let snapshot = "pageworm.snapshot"
    public static let selection = "pageworm.selection"
    public static let activeSession = "pageworm.activeSession"
    public static let pendingReadLaunch = "pageworm.pendingReadLaunch"
    public static let onboardingDraft = "pageworm.onboardingDraft"
    public static let openReadNotification = "com.pageworm.openRead"
}

public enum AppGroupDefaults {
    public static func suite() -> UserDefaults {
        UserDefaults(suiteName: SharedKeys.appGroupID) ?? .standard
    }
}
