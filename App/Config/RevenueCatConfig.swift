import Foundation

/// Replace the API key after you create the RevenueCat project.
/// Offering and product identifiers are the ones the paywall asks for.
enum RevenueCatConfig {
    static let apiKey = "appl_REPLACE_WITH_REVENUECAT_PUBLIC_SDK_KEY"
    static let premiumEntitlementID = "premium"
    static let defaultOfferingID = "default"
    static let downsellOfferingID = "downsell"
    static let annualPackageID = "$rc_annual"
    static let monthlyPackageID = "$rc_monthly"
    static let annualProductID = "pageworm_annual"
    static let monthlyProductID = "pageworm_monthly"
    static let annualDisplayPrice = "$39.99"
    static let monthlyDisplayPrice = "$6.99"
    static let trialDays = 7
    static let termsURL = URL(string: "https://pageworm.app/terms")!
    static let privacyURL = URL(string: "https://pageworm.app/privacy")!

    static var isPlaceholder: Bool {
        apiKey.contains("REPLACE")
    }
}
