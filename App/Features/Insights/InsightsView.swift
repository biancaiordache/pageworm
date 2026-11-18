import DeviceActivity
import SwiftUI
import UIKit
import PagewormCore
import PagewormDesign

struct InsightsView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(ScreenTimeManager.self) private var screenTime
    @Environment(AppRouter.self) private var router
    @Query private var books: [Book]
    @Query private var profiles: [UserProfile]
    @Query private var sessions: [ReadingSessionRecord]

    @State private var shareURL: URL?
    @State private var shareImage: UIImage?

    var body: some View {
        NavigationStack {
            PaperScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        weekCard
                        forecastCard
                        shelfCard
                        scrollCard
                        wrapCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Insights")
        }
    }

    private var week: WeekStats {
        WeekMath.summarize(
            sessions: sessions.compactMap { session in
                guard let ended = session.endedAt, let end = session.endPage else { return nil }
                return (ended, SessionRules.pagesRead(start: session.startPage, end: end), session.durationSeconds)
            },
            now: Date(),
            calendar: .current
        )
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("This week")
                .font(PagewormFont.rounded(.headline, weight: .bold))
            Text("\(week.pages) pages · \(week.minutes) minutes · \(week.sessions) sessions")
                .font(PagewormFont.rounded(.body))
        }
        .card()
    }

    @ViewBuilder
    private var forecastCard: some View {
        if let book = books.first(where: \.isCurrent) ?? books.first(where: { $0.shelf == .currentlyReading }),
           let remaining = book.remainingPages {
            let built = PaceBuilder.pace(context: context)
            if let forecast = ForecastMath.forecast(remainingPages: remaining, pace: built.pace, today: Date(), calendar: .current) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(book.title)
                        .font(PagewormFont.rounded(.headline, weight: .bold))
                    Text("\(DurationText.hours(forecast.hoursRemaining)) · \(forecast.sessionsRemaining) sessions · \(forecast.finishDate.formatted(date: .abbreviated, time: .omitted))")
                    if subscriptions.isPremium {
                        let app = profiles.first?.distractingApps.first ?? "scroll"
                        Text("Swap one daily \(app) hour and you finish \(forecast.swappedFinishDate.formatted(date: .abbreviated, time: .omitted)). That's about \(Int(forecast.swappedHourPages.rounded())) extra pages a day.")
                            .foregroundStyle(Color.pwMoss)
                    } else {
                        Button("See the date if you swap a scroll hour") { router.showPaywall = true }
                            .font(PagewormFont.rounded(.subheadline, weight: .semibold))
                    }
                    if built.isEstimated {
                        Text("Pace is still the 30 pages/hour estimate.")
                            .font(PagewormFont.rounded(.caption))
                            .foregroundStyle(Color.pwInkSoft)
                    }
                }
                .card()
            }
        }
    }

    private var shelfCard: some View {
        let open = books.filter { $0.shelf == .toRead || $0.shelf == .currentlyReading }
        let known = open.compactMap(\.remainingPages).reduce(0, +)
        let unknown = open.filter { $0.pageCount == nil }.count
        let days = ForecastMath.shelfDays(remainingPages: known, pace: PaceBuilder.pace(context: context).pace)
        return VStack(alignment: .leading, spacing: 8) {
            Text("The shelf")
                .font(PagewormFont.rounded(.headline, weight: .bold))
            if subscriptions.isPremium, let days {
                Text(InkyCopy.shelfLine(days: days))
                if unknown > 0 {
                    Text("\(unknown) books still need a page count, so they're not in that number.")
                        .font(PagewormFont.rounded(.caption))
                        .foregroundStyle(Color.pwInkSoft)
                }
            } else {
                Text("Plus will tell you how many days the shelf is at your pace.")
                Button("Unlock the countdown") { router.showPaywall = true }
                    .font(PagewormFont.rounded(.subheadline, weight: .semibold))
            }
        }
        .card()
    }

    private var scrollCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scroll time, in pages")
                .font(PagewormFont.rounded(.headline, weight: .bold))
            if subscriptions.isPremium && screenTime.isAuthorized {
                DeviceActivityReport(.weeklyScroll, filter: reportFilter)
                    .frame(height: 280)
                Text("This view is drawn by the report extension from Screen Time. It stays empty until a device has usage to report.")
                    .font(PagewormFont.rounded(.caption))
                    .foregroundStyle(Color.pwInkSoft)
            } else if !subscriptions.isPremium {
                Text("Plus turns hours you didn't give those apps into pages.")
                Button("Unlock the weekly report") { router.showPaywall = true }
                    .font(PagewormFont.rounded(.subheadline, weight: .semibold))
            } else {
                Text("Turn on Screen Time and this card can read the week.")
                    .foregroundStyle(Color.pwInkSoft)
            }
        }
        .card()
    }

    private var reportFilter: DeviceActivityFilter {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: end)),
            users: .all,
            devices: .init([.iPhone]),
            applications: screenTime.selection.applicationTokens,
            categories: screenTime.selection.categoryTokens,
            webDomains: screenTime.selection.webDomainTokens
        )
    }

    private var wrapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Share card")
                .font(PagewormFont.rounded(.headline, weight: .bold))
            if subscriptions.isPremium {
                WrapCardView(model: wrapModel, story: false)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Button("Make a story card") { renderCard() }
                    .buttonStyle(InkButtonStyle())
                if let shareURL {
                    ShareLink(item: shareURL, preview: SharePreview("Inky's week", image: Image(uiImage: shareImage ?? UIImage()))) {
                        Text("Share")
                    }
                    .font(PagewormFont.rounded(.headline, weight: .semibold))
                }
            } else {
                Text("Plus draws a story card with Inky, your streak, and the week's pages.")
                Button("Unlock share cards") { router.showPaywall = true }
                    .font(PagewormFont.rounded(.subheadline, weight: .semibold))
            }
        }
        .card()
    }

    private var wrapModel: WrapModel {
        let state = Store.streak(context).state
        let book = books.first(where: \.isCurrent)
        return WrapModel(
            name: profiles.first?.name ?? "",
            pages: week.pages,
            streak: state.currentStreak,
            bookTitle: book?.title,
            line: InkyCopy.wrapLine(name: profiles.first?.name ?? "", pages: week.pages, streak: state.currentStreak)
        )
    }

    private func renderCard() {
        let view = WrapCardView(model: wrapModel, story: true)
            .frame(width: 1080, height: 1920)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1920)
        guard let image = renderer.uiImage, let data = image.pngData() else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("inky-wrap.png")
        try? data.write(to: url)
        shareImage = image
        shareURL = url
    }
}

struct WrapModel {
    var name: String
    var pages: Int
    var streak: Int
    var bookTitle: String?
    var line: String
}

struct WrapCardView: View {
    var model: WrapModel
    var story: Bool

    var body: some View {
        let pagesSize: CGFloat = story ? 160 : 56
        let bodySize: CGFloat = story ? 42 : 18
        ZStack {
            LinearGradient(colors: [Color.pwPaper, Color.pwSage.opacity(0.55)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: story ? 36 : 16) {
                Text("PAGEWORM")
                    .font(.system(size: story ? 28 : 12, weight: .bold, design: .rounded))
                    .tracking(story ? 6 : 2)
                    .foregroundStyle(Color.pwMoss)
                InkyView(stage: .bookworm, mood: .happy, size: story ? 420 : 120, animated: false)
                Text("\(model.pages)")
                    .font(.system(size: pagesSize, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.pwInk)
                Text("pages this week")
                    .font(.system(size: bodySize, weight: .semibold, design: .rounded))
                Text(model.line)
                    .font(.system(size: bodySize, weight: .regular, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, story ? 80 : 20)
                if let title = model.bookTitle {
                    Text("Open: \(title)")
                        .font(.system(size: bodySize, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.pwInkSoft)
                }
                Text("\(model.streak)-day streak")
                    .font(.system(size: bodySize, weight: .bold, design: .rounded))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.pwCream, in: Capsule())
            }
            .foregroundStyle(Color.pwInk)
            .padding(story ? 72 : 20)
        }
    }
}

private extension View {
    func card() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pwCream, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .font(PagewormFont.rounded(.subheadline))
            .foregroundStyle(Color.pwInk)
    }
}
