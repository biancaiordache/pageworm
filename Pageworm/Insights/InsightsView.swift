import DeviceActivity
import FamilyControls
import PagewormCore
import SwiftData
import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var model: PagewormModel
    @Query private var books: [Book]
    @Query private var sessions: [ReadingSessionRecord]
    @State private var wrapURL: URL?

    private var reading: ReadingProgress {
        model.progress(books: books, sessions: sessions)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PaperCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("This week")
                                .font(Theme.rounded(.headline, weight: .bold))
                            Text("\(reading.weekPages) pages · \(reading.weekMinutes) minutes · \(Int(reading.pagesPerHour.rounded())) pages an hour")
                                .font(Theme.rounded(.subheadline))
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                    shelfCard
                    scrollCard
                    shareCard
                }
                .padding(20)
            }
            .background(CozyBackground())
            .navigationTitle("Insights")
            .sheet(isPresented: Binding(get: { wrapURL != nil }, set: { if !$0 { wrapURL = nil } })) {
                if let wrapURL {
                    ShareLink(item: wrapURL, preview: SharePreview("Pageworm", image: Image(systemName: "book.closed"))) {
                        Label("Share your wrap", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(24)
                    .presentationDetents([.medium])
                }
            }
        }
    }

    @ViewBuilder
    private var shelfCard: some View {
        if model.profile.isPremium {
            let shelf = reading.shelfCountdown
            PaperCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your shelf is \(shelf.days) days at your pace.")
                        .font(Theme.rounded(.headline, weight: .bold))
                    Text("\(shelf.totalPages) pages across \(shelf.knownBooks) books.")
                        .font(Theme.rounded(.subheadline))
                        .foregroundStyle(Theme.inkSoft)
                    if shelf.unknownPageBooks > 0 {
                        Text("\(shelf.unknownPageBooks) still need a page count.")
                            .font(Theme.rounded(.footnote))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
        } else {
            locked("The shelf countdown is part of Plus.")
        }
    }

    @ViewBuilder
    private var scrollCard: some View {
        if model.profile.isPremium, model.screenTimeApproved {
            VStack(alignment: .leading, spacing: 8) {
                Text("Scroll time, in pages")
                    .font(Theme.rounded(.headline, weight: .bold))
                    .foregroundStyle(Theme.ink)
                DeviceActivityReport(.init(rawValue: SharedKeys.reportContext), filter: filter)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                Text("Apple counts this from the apps you blocked. Names come from what you told Inky.")
                    .font(Theme.rounded(.caption))
                    .foregroundStyle(Theme.inkSoft)
            }
        } else {
            locked("The weekly scroll-to-pages report is part of Plus, and it needs Screen Time.")
        }
    }

    private var shareCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("A card for stories")
                    .font(Theme.rounded(.headline, weight: .bold))
                Text("Inky, your streak, and the pages. Sized for TikTok and Instagram.")
                    .font(Theme.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
                if model.profile.isPremium {
                    Button("Make a wrap") {
                        wrapURL = WrapRenderer.png(progress: reading, name: model.profile.name)
                        if wrapURL == nil { model.banner = "I couldn't draw the card." }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Unlock wraps") { model.showPaywall = true }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }

    private func locked(_ text: String) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(text)
                    .font(Theme.rounded(.subheadline))
                    .foregroundStyle(Theme.ink)
                Button("See Plus") { model.showPaywall = true }
                    .buttonStyle(QuietButtonStyle())
            }
        }
    }

    private var filter: DeviceActivityFilter {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        let selection = SelectionStore.load()
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: end)),
            users: .all,
            devices: .init([.iPhone]),
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens
        )
    }
}
