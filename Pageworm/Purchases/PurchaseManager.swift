import Foundation
import RevenueCat

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var isPremium = false
    @Published private(set) var configured = false
    @Published private(set) var annual: Package?
    @Published private(set) var monthly: Package?
    @Published var lastError: String?
    var onPremiumChange: ((Bool) -> Void)?

    func start() {
        guard !RevenueCatConfig.isPlaceholder else {
            configured = false
            return
        }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
        configured = true
        Task { await refresh() }
    }

    func refresh() async {
        guard configured else { return }
        do {
            let offerings = try await Purchases.shared.offerings()
            let offering = offerings.offering(identifier: RevenueCatConfig.offeringID) ?? offerings.current
            annual = pick(offering, id: RevenueCatConfig.annualProductID, type: .annual)
            monthly = pick(offering, id: RevenueCatConfig.monthlyProductID, type: .monthly)
            apply(try await Purchases.shared.customerInfo())
        } catch {
            lastError = error.localizedDescription
        }
    }

    func purchase(_ package: Package) async -> Bool {
        guard configured else {
            lastError = "Add the RevenueCat public SDK key in RevenueCatConfig.swift. The paywall is showing the planned prices until then."
            return false
        }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return false }
            apply(result.customerInfo)
            if !isPremium {
                lastError = "The purchase went through, but the \"\(RevenueCatConfig.entitlementID)\" entitlement is not active. Check the RevenueCat entitlement name."
            }
            return isPremium
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async -> Bool {
        guard configured else {
            lastError = "Add the RevenueCat public SDK key in RevenueCatConfig.swift before restoring."
            return false
        }
        do {
            apply(try await Purchases.shared.restorePurchases())
            if !isPremium {
                lastError = "No active \(RevenueCatConfig.entitlementID) entitlement on this Apple ID."
            }
            return isPremium
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func price(for package: Package?, fallback: String) -> String {
        package?.storeProduct.localizedPriceString ?? fallback
    }

    func annualIncludesTrial(_ package: Package?) -> Bool {
        if !configured { return true }
        return package?.storeProduct.introductoryDiscount != nil
    }

    private func apply(_ info: CustomerInfo) {
        let active = info.entitlements[RevenueCatConfig.entitlementID]?.isActive == true
        isPremium = active
        onPremiumChange?(active)
    }

    private func pick(_ offering: Offering?, id: String, type: PackageType) -> Package? {
        guard let offering else { return nil }
        if let matched = offering.availablePackages.first(where: { $0.storeProduct.productIdentifier == id }) {
            return matched
        }
        return type == .annual ? offering.annual : offering.monthly
    }
}
