import Foundation

/// Public iOS SDK key. Safe to ship in the app. The secret key stays in RevenueCat.
/// App Store listing name is "Pageworm: Read More" (Apple ID 6836330820).
/// The name under the icon is CFBundleDisplayName, "Pageworm".
enum RevenueCatConfig {
    static let apiKey = "appl_oSkiHywUPcxzCUYSuFqnkjIvGGc"
    static let offeringID = "default"
    static let entitlementID = "premium"
    static let annualPackageID = "$rc_annual"
    static let monthlyPackageID = "$rc_monthly"
    static let annualProductID = "pageworm_annual"
    static let monthlyProductID = "pageworm_monthly"
    static let annualPrice = "$39.99"
    static let monthlyPrice = "$6.99"
    static let trialDays = 7

    static var isPlaceholder: Bool {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty || key.contains("REPLACE")
    }
}
