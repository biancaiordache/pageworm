import PagewormCore
import RevenueCat
import SwiftUI

struct PaywallView: View {
    enum Mode { case annual, monthly }

    var mode: Mode
    var onPurchased: () -> Void
    var onDecline: () -> Void

    @EnvironmentObject private var purchases: PurchaseManager
    @State private var page = 0
    @State private var working = false

    var body: some View {
        VStack(spacing: 0) {
            if mode == .annual {
                TabView(selection: $page) {
                    benefits.tag(0)
                    timeline.tag(1)
                    annualOffer.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
            } else {
                monthlyOffer
            }
        }
        .padding(.bottom, 8)
        .alert("Pageworm Plus", isPresented: Binding(
            get: { purchases.lastError != nil },
            set: { if !$0 { purchases.lastError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchases.lastError ?? "")
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 16) {
            InkyView(stage: .chapterChomper, mood: .happy, size: 150)
            Text("I'll keep the door shut.")
                .font(Theme.rounded(.title, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("You keep the pages turning. Plus is how I grow up with you, and how more than one app stays covered.")
                .font(Theme.rounded(.body))
                .foregroundStyle(Theme.inkSoft)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(PremiumFeature.allCases.prefix(6), id: \.rawValue) { feature in
                    Label(feature.title, systemImage: "checkmark")
                        .font(Theme.rounded(.subheadline, weight: .medium))
                        .foregroundStyle(Theme.ink)
                }
            }
            Spacer()
            Button("Show the trial") { withAnimation { page = 1 } }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Seven quiet days")
                .font(Theme.rounded(.title, weight: .bold))
                .foregroundStyle(Theme.ink)
            timelineRow(day: "Day 1", text: "Plus unlocks. Inky can cover every app you picked, and he starts to grow.")
            timelineRow(day: "Day 6", text: "I'll remind you the trial is ending.")
            timelineRow(day: "Day 7", text: "It becomes \(annualPrice) a year. Cancel before then and you won't be charged.")
            Spacer()
            Button("See the price") { withAnimation { page = 2 } }
                .buttonStyle(PrimaryButtonStyle())
            decline("Not now")
        }
        .padding(24)
    }

    private var annualOffer: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(purchases.annualIncludesTrial(purchases.annual) ? "Start with 7 free days" : "Pageworm Plus, yearly")
                .font(Theme.rounded(.title, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Then \(annualPrice) a year. That's the plan with a trial, the streak freeze, the wraps, and every door.")
                .font(Theme.rounded(.body))
                .foregroundStyle(Theme.inkSoft)
            Text("Payment is charged to your Apple ID. A subscription renews unless you cancel at least 24 hours before the trial or the period ends.")
                .font(Theme.rounded(.caption))
                .foregroundStyle(Theme.inkSoft)
            Spacer()
            Button(working ? "Talking to the App Store…" : (purchases.annualIncludesTrial(purchases.annual) ? "Start the free trial" : "Subscribe yearly")) {
                buy(purchases.annual)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(working)
            Button("Restore purchase") { restore() }
                .font(Theme.rounded(.footnote, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity)
            decline("No thanks")
        }
        .padding(24)
    }

    private var monthlyOffer: some View {
        VStack(alignment: .leading, spacing: 16) {
            InkyView(stage: .pageNibbler, mood: .happy, size: 130)
            Text("A smaller yes")
                .font(Theme.rounded(.title, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("\(monthlyPrice) a month, no trial. Same Plus. Cancel whenever the month has done its job.")
                .font(Theme.rounded(.body))
                .foregroundStyle(Theme.inkSoft)
            Spacer()
            Button(working ? "One moment…" : "Continue monthly") { buy(purchases.monthly) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(working)
            Button("Restore purchase") { restore() }
                .font(Theme.rounded(.footnote, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity)
            decline("Continue with the free plan")
        }
        .padding(24)
    }

    private var annualPrice: String {
        purchases.price(for: purchases.annual, fallback: RevenueCatConfig.annualPrice)
    }

    private var monthlyPrice: String {
        purchases.price(for: purchases.monthly, fallback: RevenueCatConfig.monthlyPrice)
    }

    private func timelineRow(day: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(day)
                .font(Theme.rounded(.subheadline, weight: .bold))
                .foregroundStyle(Theme.burgundy)
                .frame(width: 64, alignment: .leading)
            Text(text)
                .font(Theme.rounded(.subheadline))
                .foregroundStyle(Theme.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func decline(_ title: String) -> some View {
        Button(title, action: onDecline)
            .buttonStyle(QuietButtonStyle())
    }

    private func buy(_ package: Package?) {
        guard let package else {
            if RevenueCatConfig.isPlaceholder {
                purchases.lastError = "The RevenueCat key is still a placeholder, so the App Store isn't connected. You can continue on the free plan and add the key later."
            } else {
                purchases.lastError = "I couldn't find that package in the \(RevenueCatConfig.offeringID) offering."
            }
            return
        }
        working = true
        Task {
            let unlocked = await purchases.purchase(package)
            working = false
            if unlocked { onPurchased() }
        }
    }

    private func restore() {
        working = true
        Task {
            let unlocked = await purchases.restore()
            working = false
            if unlocked { onPurchased() }
        }
    }
}
