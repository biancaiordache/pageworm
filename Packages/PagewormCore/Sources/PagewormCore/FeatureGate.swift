import Foundation

public enum PremiumFeature: String, Codable, CaseIterable {
    case multipleBlockedApps
    case storyGraphImport
    case strictMode
    case customUnlockLength
    case weeklyScrollReport
    case wrapCards
    case streakFreeze
    case inkyEvolution
    case tbrCountdown
    case liveActivity
    case homeWidget
    case emergencyUnlock

    public var title: String {
        switch self {
        case .multipleBlockedApps: "More than one blocked app"
        case .storyGraphImport: "StoryGraph import"
        case .strictMode: "Strict mode"
        case .customUnlockLength: "Custom unlock length"
        case .weeklyScrollReport: "Weekly scroll-to-pages report"
        case .wrapCards: "Shareable wrap cards"
        case .streakFreeze: "Weekly streak freeze"
        case .inkyEvolution: "Inky's growth"
        case .tbrCountdown: "Shelf countdown"
        case .liveActivity: "Reading Live Activity"
        case .homeWidget: "Home Screen widget"
        case .emergencyUnlock: "Emergency unlock"
        }
    }
}

public struct FeatureGate: Equatable {
    public var isPremium: Bool

    public init(isPremium: Bool) {
        self.isPremium = isPremium
    }

    public static let freeBlockedAppLimit = 1
    public static let appleTokenLimit = 50

    public func allows(_ feature: PremiumFeature) -> Bool {
        isPremium
    }

    public func withinSelectionLimit(appCount: Int, webCount: Int, categoryCount: Int) -> Bool {
        if appCount > Self.appleTokenLimit || webCount > Self.appleTokenLimit || categoryCount > Self.appleTokenLimit {
            return false
        }
        if isPremium { return true }
        if categoryCount > 0 { return false }
        return appCount + webCount <= Self.freeBlockedAppLimit
    }
}
