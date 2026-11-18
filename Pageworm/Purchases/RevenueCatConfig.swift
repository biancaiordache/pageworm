import Foundation

/// Replace the placeholder before TestFlight. Product IDs must match App Store Connect and the RevenueCat offering.
enum RevenueCatConfig {
    static let apiKey = "appl_REPLACE_WITH_REVENUECAT_PUBLIC_SDK_KEY"
    static let offeringID = "default"
    static let annualProductID = "pageworm_annual"
    static let monthlyProductID = "pageworm_monthly"
    static let entitlementID = "premium"
    static let annualPrice = "$39.99"
    static let monthlyPrice = "$6.99"
    static let trialDays = 7

    static var isPlaceholder: Bool {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || apiKey.contains("REPLACE")
    }
}
