import Foundation

public enum PagewormFeature: String, CaseIterable, Sendable {
    case extraBlockedApps
    case categoriesAndWeb
    case storyGraphImport
    case customUnlockWindow
    case strictMode
    case weeklyScrollReport
    case streakFreeze
    case inkyEvolution
    case shareCards
    case widget
    case liveActivity
    case swappedHourForecast
    case shelfCountdown
}

public enum Access {
    public static let freeBlockedApplicationLimit = 1

    public static func allows(_ feature: PagewormFeature, isPremium: Bool) -> Bool {
        isPremium
    }

    public static func allowedApplicationCount(selected: Int, isPremium: Bool) -> Int {
        let selected = max(0, selected)
        return isPremium ? selected : min(selected, freeBlockedApplicationLimit)
    }

    public static func selectionFitsFreeTier(applicationCount: Int, categoryCount: Int, webDomainCount: Int) -> Bool {
        categoryCount == 0 && webDomainCount == 0 && applicationCount <= freeBlockedApplicationLimit
    }
}
