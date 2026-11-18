import Foundation

/// Identifiers shared by the app, extensions, and widget.
/// If you change the App Group, update every `.entitlements` file to match.
public enum PagewormIDs {
    public static let appGroup = "group.com.pageworm.shared"
    public static let urlScheme = "pageworm"
    public static let managedSettingsStore = "pageworm"
    public static let stateFileName = "pageworm-state.json"
    public static let selectionFileName = "selection.plist"
    public static let pendingReadKey = "pageworm.pendingRead"
}

public enum ActivityNames {
    public static let dailyBlock = "pageworm.dailyBlock"
    public static let unlockWindow = "pageworm.unlockWindow"
}

public enum ReportNames {
    public static let weeklyScroll = "pageworm.weeklyScroll"
}
