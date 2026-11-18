import Combine
import PagewormCore
import SwiftData
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: PagewormModel
    @Query private var books: [Book]
    @Query private var sessions: [ReadingSessionRecord]
    @State private var now = Date()

    private var reading: ReadingProgress {
        model.progress(books: books, sessions: sessions)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let banner = model.banner {
                        Text(banner)
                            .font(Theme.rounded(.subheadline))
                            .foregroundStyle(Theme.ink)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.gold.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    unlockCard
                    bookCard
                    if model.profile.strictMode {
                        emergency
                    }
                    if !model.screenTimeApproved {
                        Text("Screen Time isn't on yet, so the doors stay open. You can allow it in Settings.")
                            .font(Theme.rounded(.footnote))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .background(CozyBackground())
            .navigationTitle("Pageworm")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            model.resumeIfNeeded(books: books)
        }
        .fullScreenCover(item: readingCover) { book in
            ReadingSessionView(book: book)
        }
        .sheet(item: Binding(get: { model.finishedCelebration }, set: { model.finishedCelebration = $0 })) { book in
            FinishSheet(book: book)
        }
    }

    private var readingCover: Binding<Book?> {
        Binding(
            get: { books.first { $0.id == model.readingBookID } },
            set: { model.readingBookID = $0?.id }
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            InkyView(stage: reading.stage, mood: reading.mood, size: 120)
            VStack(alignment: .leading, spacing: 6) {
                Text(reading.line())
                    .font(Theme.rounded(.headline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 8) {
                    Label("\(reading.streak.currentStreak) day streak", systemImage: "flame")
                    if reading.streak.freezeUsedThisWeek, model.profile.isPremium {
                        Text("Freeze used")
                    }
                }
                .font(Theme.rounded(.caption, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                if !model.profile.isPremium, reading.realStage > reading.stage {
                    Button("Inky wants to grow") { model.showPaywall = true }
                        .font(Theme.rounded(.caption, weight: .bold))
                        .foregroundStyle(Theme.burgundy)
                }
            }
        }
    }

    @ViewBuilder
    private var unlockCard: some View {
        let snapshot = SharedStore.snapshot(in: AppGroupDefaults.suite())
        if let unlock = snapshot.unlock, unlock.contains(now) {
            PaperCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text(unlock.source == .emergency ? "Emergency door" : "Door is open")
                        .font(Theme.rounded(.headline, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(timerInterval: now...unlock.endsAt, countsDown: true)
                        .font(Theme.rounded(.title2, weight: .bold))
                        .foregroundStyle(Theme.burgundy)
                    Text("When this hits zero, the shield comes back.")
                        .font(Theme.rounded(.footnote))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 }
        }
    }

    @ViewBuilder
    private var bookCard: some View {
        if let book = reading.currentBook {
            PaperCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        BookCover(title: book.title, url: book.coverURL)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(Theme.rounded(.headline, weight: .bold))
                                .foregroundStyle(Theme.ink)
                            Text(book.author)
                                .font(Theme.rounded(.subheadline))
                                .foregroundStyle(Theme.inkSoft)
                            if let pages = book.pageCount {
                                Text("\(book.currentPage) of \(pages)")
                                    .font(Theme.rounded(.caption, weight: .semibold))
                                    .foregroundStyle(Theme.burgundy)
                            }
                        }
                    }
                    if let forecast = reading.forecast(for: book) {
                        ForecastBlock(forecast: forecast, appName: OnboardingCopy.scrollSwapName(apps: model.profile.distractingApps))
                    } else {
                        Text("Add a page count and I'll tell you the finish date.")
                            .font(Theme.rounded(.footnote))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Button(model.activeSession == nil ? "Start reading" : "Back to the timer") {
                        if model.activeSession == nil {
                            model.beginReading(book)
                        } else {
                            model.readingBookID = book.id
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        } else {
            PaperCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("The shelf is empty.")
                        .font(Theme.rounded(.headline, weight: .bold))
                    Text("Bring a Goodreads export, or add one book by hand.")
                        .font(Theme.rounded(.subheadline))
                        .foregroundStyle(Theme.inkSoft)
                    Button("Open the library") { model.tab = .library }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }

    private var emergency: some View {
        let allowed = EmergencyUnlockPolicy.canRedeem(
            lastRedeemedAt: model.profile.lastEmergencyUnlockAt,
            now: Date(),
            calendar: PagewormCalendar.make()
        )
        return PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Strict mode")
                    .font(Theme.rounded(.headline, weight: .bold))
                    .foregroundStyle(Theme.ink)
                if allowed {
                    HoldButton(title: "Hold for emergency", hint: "Once this week. \(model.profile.unlockMinutes) minutes.") {
                        model.banner = model.redeemEmergency()
                    }
                } else {
                    Text("You've used this week's emergency. Inky believes in you.")
                        .font(Theme.rounded(.subheadline))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
    }
}

struct ForecastBlock: View {
    var forecast: FinishForecast
    var appName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(formatHours(forecast.hoursRemaining)) · \(forecast.sessionsRemaining) sessions · \(forecast.finishDate.formatted(date: .abbreviated, time: .omitted))")
                .font(Theme.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Swap your daily \(appName) hour and you finish \(forecast.fasterFinishDate.formatted(date: .abbreviated, time: .omitted)), \(forecast.daysSaved) days sooner.")
                .font(Theme.rounded(.footnote))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private func formatHours(_ hours: Double) -> String {
        if hours < 1 { return "\(max(1, Int((hours * 60).rounded()))) min" }
        return String(format: "%.1f hours", hours)
    }
}

struct BookCover: View {
    var title: String
    var url: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.spine)
            Text(title)
                .font(Theme.rounded(.caption2, weight: .bold))
                .foregroundStyle(Theme.paper)
                .multilineTextAlignment(.center)
                .padding(6)
            if let url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    if case let .success(image) = phase {
                        image.resizable().scaledToFill()
                    }
                }
            }
        }
        .frame(width: 68, height: 102)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel("Cover of \(title)")
    }
}

struct FinishSheet: View {
    @EnvironmentObject private var model: PagewormModel
    @Environment(\.dismiss) private var dismiss
    var book: Book

    var body: some View {
        VStack(spacing: 16) {
            InkyView(stage: .novelNommer, mood: .cheering, size: 180)
            Text("You finished \(book.title).")
                .font(Theme.rounded(.title, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.ink)
            Text("Inky is a little bigger for it.")
                .font(Theme.rounded(.body))
                .foregroundStyle(Theme.inkSoft)
            Button("Back to the shelf") {
                model.dismissCelebration()
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(28)
        .background(CozyBackground())
    }
}
