import SwiftUI
import PagewormCore
import PagewormDesign

struct PaywallView: View {
    var onFinished: () -> Void
    @Environment(SubscriptionManager.self) private var subscriptions
    @State private var showingDownsell = false
    @State private var working = false

    var body: some View {
        PaperScreen {
            if showingDownsell {
                downsell
            } else {
                annual
            }
        }
    }

    private var annual: some View {
        ScrollView {
            VStack(spacing: 22) {
                InkyView(stage: .bookworm, mood: .happy, size: 150)
                Text("A library card for the rest of it")
                    .font(PagewormFont.rounded(.title, weight: .bold))
                    .foregroundStyle(Color.pwInk)
                    .multilineTextAlignment(.center)
                Text("7 days free, then \(subscriptions.annualPrice) a year.")
                    .font(PagewormFont.rounded(.body))
                    .foregroundStyle(Color.pwInkSoft)
                timeline
                featureList
                Button {
                    Task { await buyAnnual() }
                } label: {
                    Text(working ? "One moment…" : "Start 7-day free trial")
                }
                .buttonStyle(InkButtonStyle())
                .disabled(working)
                Button("Not now") { withAnimation { showingDownsell = true } }
                    .font(PagewormFont.rounded(.body, weight: .semibold))
                    .foregroundStyle(Color.pwInkSoft)
                legal
            }
            .padding(24)
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 16) {
            timelineRow(day: "Day 1", detail: "Today. Full access, and Inky starts the trial.")
            timelineRow(day: "Day 6", detail: "I'll remind you before anything is charged.")
            timelineRow(day: "Day 7", detail: "The trial ends. Stay for \(subscriptions.annualPrice)/year, or cancel.")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pwCream, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func timelineRow(day: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(day)
                .font(PagewormFont.rounded(.subheadline, weight: .bold))
                .foregroundStyle(Color.pwMoss)
                .frame(width: 58, alignment: .leading)
            Text(detail)
                .font(PagewormFont.rounded(.subheadline))
                .foregroundStyle(Color.pwInk)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Block every app that steals chapters")
            label("Strict mode and a weekly emergency unlock")
            label("Streak freezes, Inky's later forms, widgets")
            label("Scroll-time-to-pages and story cards")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func label(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "bookmark.fill")
                .foregroundStyle(Color.pwGold)
            Text(text)
                .font(PagewormFont.rounded(.subheadline))
                .foregroundStyle(Color.pwInk)
        }
    }

    private var downsell: some View {
        VStack(spacing: 20) {
            Spacer()
            InkyView(stage: .sprout, mood: .sleepy, size: 150)
            Text("A smaller library card")
                .font(PagewormFont.rounded(.title, weight: .bold))
                .foregroundStyle(Color.pwInk)
            Text("\(subscriptions.monthlyPrice) a month. No trial. Cancel whenever.")
                .font(PagewormFont.rounded(.body))
                .foregroundStyle(Color.pwInkSoft)
                .multilineTextAlignment(.center)
            Button {
                Task { await buyMonthly() }
            } label: {
                Text(working ? "One moment…" : "Continue monthly")
            }
            .buttonStyle(InkButtonStyle())
            .disabled(working)
            Button("I'll stay on the free plan") { onFinished() }
                .font(PagewormFont.rounded(.body, weight: .semibold))
                .foregroundStyle(Color.pwInkSoft)
            legal
            Spacer()
        }
        .padding(24)
    }

    private var legal: some View {
        VStack(spacing: 8) {
            Text("Payment is charged to your Apple ID. A subscription renews unless you cancel at least 24 hours before the period ends. Manage it in Settings → Apple ID.")
                .font(PagewormFont.rounded(.caption2))
                .foregroundStyle(Color.pwInkSoft)
                .multilineTextAlignment(.center)
            if !subscriptions.isConfigured {
                Text("The RevenueCat key is still a placeholder, so this build won't charge anyone.")
                    .font(PagewormFont.rounded(.caption2))
                    .foregroundStyle(Color.pwInkSoft)
                    .multilineTextAlignment(.center)
            }
            if let error = subscriptions.lastError {
                Text(error)
                    .font(PagewormFont.rounded(.caption))
                    .foregroundStyle(Color.pwSpine)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 16) {
                Link("Terms", destination: RevenueCatConfig.termsURL)
                Link("Privacy", destination: RevenueCatConfig.privacyURL)
                Button("Restore") { Task { _ = await subscriptions.restore() } }
            }
            .font(PagewormFont.rounded(.caption, weight: .semibold))
        }
    }

    private func buyAnnual() async {
        working = true
        defer { working = false }
        if await subscriptions.purchaseAnnual() {
            onFinished()
        }
    }

    private func buyMonthly() async {
        working = true
        defer { working = false }
        if await subscriptions.purchaseMonthly() {
            onFinished()
        }
    }
}
