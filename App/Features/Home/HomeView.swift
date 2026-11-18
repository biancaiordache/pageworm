import SwiftUI
import PagewormCore
import PagewormDesign

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(ScreenTimeManager.self) private var screenTime
    @Environment(AppRouter.self) private var router
    @Query private var books: [Book]
    @Query private var profiles: [UserProfile]
    @Query private var streaks: [StreakRecord]

    var body: some View {
        PaperScreen {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    if let end = screenTime.unlockEndsAt, end > Date() {
                        unlockCard(until: end)
                    }
                    if !screenTime.isAuthorized {
                        banner("Screen Time isn't guarding anything yet. You can turn it on in Settings.")
                    }
                    if let message = screenTime.lastMessage {
                        banner(message)
                    }
                    if let book = current {
                        bookCard(book)
                    } else {
                        emptyBook
                    }
                    Button("Start reading") { router.showReading = true }
                        .buttonStyle(InkButtonStyle())
                }
                .padding(20)
            }
        }
    }

    private var profile: UserProfile? { profiles.first }
    private var streak: StreakRecord? { streaks.first }
    private var current: Book? {
        books.first(where: \.isCurrent) ?? books.first(where: { $0.shelf == .currentlyReading && $0.finishedAt == nil })
    }

    private var header: some View {
        let state = streak?.state ?? StreakState()
        let allowFreeze = Access.allows(.streakFreeze, isPremium: subscriptions.isPremium)
        let health = StreakEngine.health(state: state, today: Date(), allowFreeze: allowFreeze, calendar: .current)
        let finished = books.filter { $0.finishedAt != nil && $0.countsTowardInky }.count
        let stage = InkyEvolution.displayedStage(finishedBooks: finished, streak: state.currentStreak, isPremium: subscriptions.isPremium)
        let mood = InkyEvolution.mood(lastReadDay: state.lastQualifiedDay, now: Date(), calendar: .current)
        return VStack(spacing: 12) {
            InkyView(stage: stage, mood: mood, size: 168)
            InkyBubble(text: speech(mood: mood, health: health))
            HStack {
                Label(streakLabel(health), systemImage: "flame")
                Spacer()
                Text(stage.title)
            }
            .font(PagewormFont.rounded(.subheadline, weight: .semibold))
            .foregroundStyle(Color.pwInk)
            if !subscriptions.isPremium, InkyEvolution.stage(finishedBooks: finished, streak: state.currentStreak) != .sprout {
                Text("Inky wants to grow into a \(InkyEvolution.stage(finishedBooks: finished, streak: state.currentStreak).title). That's Plus.")
                    .font(PagewormFont.rounded(.footnote))
                    .foregroundStyle(Color.pwInkSoft)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func speech(mood: InkyMood, health: StreakHealth) -> String {
        let name = profile?.name ?? ""
        switch mood {
        case .happy:
            return name.isEmpty ? "The page is open. I'm happy." : "The page is open, \(name). I'm happy."
        case .sleepy:
            if case .atRisk(_) = health { return "I'm getting sleepy. A few pages would wake the streak." }
            return "I'm here, a little sleepy. Want to read?"
        case .missingYou:
            return "I missed you. The book didn't."
        }
    }

    private func streakLabel(_ health: StreakHealth) -> String {
        switch health {
        case .empty: return "No streak yet"
        case .active(let days): return "\(days)-day streak"
        case .atRisk(let days): return "\(days)-day streak, at risk"
        case .savedByFreeze(let days): return "\(days)-day streak, freeze used"
        case .broken: return "Streak cooled off"
        }
    }

    private func bookCard(_ book: Book) -> some View {
        let built = PaceBuilder.pace(context: context)
        let forecast = book.remainingPages.flatMap {
            ForecastMath.forecast(remainingPages: $0, pace: built.pace, today: Date(), calendar: .current)
        }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                BookCover(url: book.coverURL, title: book.title)
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(PagewormFont.rounded(.headline, weight: .bold))
                    Text(book.authors)
                        .font(PagewormFont.rounded(.subheadline))
                        .foregroundStyle(Color.pwInkSoft)
                    if let total = book.pageCount {
                        Text("Page \(book.currentPage) of \(total)")
                            .font(PagewormFont.rounded(.subheadline, weight: .semibold))
                    }
                }
            }
            if let forecast {
                Text("About \(formattedHours(forecast.hoursRemaining)) left · \(forecast.sessionsRemaining) sessions · \(forecast.finishDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(PagewormFont.rounded(.subheadline))
                    .foregroundStyle(Color.pwInk)
                if built.isEstimated {
                    Text("Estimated at 30 pages an hour until we time a session.")
                        .font(PagewormFont.rounded(.caption))
                        .foregroundStyle(Color.pwInkSoft)
                }
            } else {
                Text("Add a page count and I'll tell you the finish date.")
                    .font(PagewormFont.rounded(.subheadline))
                    .foregroundStyle(Color.pwInkSoft)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pwCream, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var emptyBook: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No current book")
                .font(PagewormFont.rounded(.headline, weight: .bold))
            Text("Import a shelf or add one by hand. I'll keep the forecast once it has pages.")
                .font(PagewormFont.rounded(.subheadline))
                .foregroundStyle(Color.pwInkSoft)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pwCream, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func unlockCard(until end: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(end.timeIntervalSince(context.date)))
            Text("Apps are open for \(remaining / 60)m \(remaining % 60)s")
                .font(PagewormFont.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(Color.pwInk)
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Color.pwSage.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func banner(_ text: String) -> some View {
        Text(text)
            .font(PagewormFont.rounded(.footnote))
            .foregroundStyle(Color.pwInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.pwGold.opacity(0.25), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func formattedHours(_ hours: Double) -> String {
        if hours < 1 {
            return "\(max(1, Int((hours * 60).rounded()))) min"
        }
        return DurationText.hours(hours)
    }
}

@MainActor
@Observable
final class AppRouter {
    var showReading = false
    var showPaywall = false
}
