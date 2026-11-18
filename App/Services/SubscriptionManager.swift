import Foundation
import Observation
import RevenueCat

@MainActor
@Observable
final class SubscriptionManager {
    var isPremium = false
    var isConfigured = false
    var annualPrice = RevenueCatConfig.annualDisplayPrice
    var monthlyPrice = RevenueCatConfig.monthlyDisplayPrice
    var lastError: String?
    private var annualPackage: Package?
    private var monthlyPackage: Package?
    private var configured = false

    func configure() {
        guard !configured else { return }
        configured = true
        guard !RevenueCatConfig.isPlaceholder else {
            isConfigured = false
            return
        }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
        isConfigured = true
        Task { await refresh() }
    }

    func refresh() async {
        guard isConfigured else { return }
        do {
            let offerings = try await Purchases.shared.offerings()
            let annualOffering = offerings.offering(identifier: RevenueCatConfig.defaultOfferingID) ?? offerings.current
            annualPackage = pick(
                offering: annualOffering,
                packageID: RevenueCatConfig.annualPackageID,
                productID: RevenueCatConfig.annualProductID,
                typed: annualOffering?.annual
            )
            let downsell = offerings.offering(identifier: RevenueCatConfig.downsellOfferingID)
            monthlyPackage = pick(
                offering: downsell,
                packageID: RevenueCatConfig.monthlyPackageID,
                productID: RevenueCatConfig.monthlyProductID,
                typed: downsell?.monthly ?? offerings.current?.monthly
            )
            if let price = annualPackage?.storeProduct.localizedPriceString { annualPrice = price }
            if let price = monthlyPackage?.storeProduct.localizedPriceString { monthlyPrice = price }
            let info = try await Purchases.shared.customerInfo()
            apply(info)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func purchaseAnnual() async -> Bool {
        await purchase(annualPackage, missing: "The annual package isn't in the \"\(RevenueCatConfig.defaultOfferingID)\" offering yet.")
    }

    func purchaseMonthly() async -> Bool {
        await purchase(monthlyPackage, missing: "The monthly package isn't in the \"\(RevenueCatConfig.downsellOfferingID)\" offering yet.")
    }

    func restore() async -> Bool {
        guard isConfigured else {
            lastError = "Add the RevenueCat public SDK key before restoring purchases."
            return false
        }
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            if !isPremium {
                lastError = "No active Pageworm Plus subscription was found."
            }
            return isPremium
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func purchase(_ package: Package?, missing: String) async -> Bool {
        guard isConfigured else {
            lastError = "Purchases aren't configured yet. Add the RevenueCat key, or continue on the free plan."
            return false
        }
        guard let package else {
            lastError = missing
            return false
        }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return false }
            apply(result.customerInfo)
            if isPremium {
                InkyNotifications.scheduleTrialReminder()
            }
            return isPremium
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func apply(_ info: CustomerInfo) {
        isPremium = info.entitlements[RevenueCatConfig.premiumEntitlementID]?.isActive == true
    }

    private func pick(offering: Offering?, packageID: String, productID: String, typed: Package?) -> Package? {
        if let typed { return typed }
        if let match = offering?.package(identifier: packageID) { return match }
        return offering?.availablePackages.first { $0.storeProduct.productIdentifier == productID }
    }
}
