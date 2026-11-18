import SwiftUI
import PagewormCore
import PagewormDesign

struct ReadingSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(ScreenTimeManager.self) private var screenTime
    @Query(sort: \Book.title) private var books: [Book]

    @State private var bookID: UUID?
    @State private var startPage = 0
    @State private var endPage = 0
    @State private var startedAt: Date?
    @State private var outcome: SessionOutcome?
    @State private var pageError: String?

    var body: some View {
        NavigationStack {
            PaperScreen {
                ScrollView {
                    VStack(spacing: 18) {
                        if let outcome {
                            result(outcome)
                        } else if startedAt != nil {
                            timer
                        } else {
                            setup
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        if startedAt == nil { dismiss() }
                    }
                    .disabled(startedAt != nil && outcome == nil)
                }
            }
        }
        .onAppear(perform: restore)
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 14) {
            InkyBubble(text: "Which book are we opening?")
            if readableBooks.isEmpty {
                Text("Add a book in the library first.")
                    .foregroundStyle(Color.pwInkSoft)
            } else {
                Picker("Book", selection: $bookID) {
                    Text("Choose").tag(Optional<UUID>.none)
                    ForEach(readableBooks) { book in
                        Text(book.title).tag(Optional(book.bookID))
                    }
                }
                .pickerStyle(.navigationLink)
                Stepper("Start page \(startPage)", value: $startPage, in: 0...20000)
                Button("Start the timer") { start() }
                    .buttonStyle(InkButtonStyle())
                    .disabled(bookID == nil)
            }
        }
    }

    private var timer: some View {
        VStack(spacing: 16) {
            InkyView(stage: .bookworm, mood: .happy, size: 120)
            if let startedAt {
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    Text(elapsed(since: startedAt, now: context.date))
                        .font(PagewormFont.rounded(.largeTitle, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.pwInk)
                }
            }
            Text(selectedBook?.title ?? "Reading")
                .font(PagewormFont.rounded(.headline))
            Stepper("End page \(endPage)", value: $endPage, in: 0...20000)
            if let pageError {
                Text(pageError).foregroundStyle(Color.pwSpine).font(PagewormFont.rounded(.footnote))
            }
            Button("Stop and save") { stop() }
                .buttonStyle(InkButtonStyle())
            Text("Five minutes and at least one page opens the apps.")
                .font(PagewormFont.rounded(.footnote))
                .foregroundStyle(Color.pwInkSoft)
                .multilineTextAlignment(.center)
        }
    }

    private func result(_ outcome: SessionOutcome) -> some View {
        VStack(spacing: 14) {
            InkyView(mood: outcome.qualified ? .happy : .sleepy, size: 140, animated: false)
            Text(outcome.qualified ? "That counts." : "That was a nibble.")
                .font(PagewormFont.rounded(.title2, weight: .bold))
                .foregroundStyle(Color.pwInk)
            Text("\(outcome.pages) pages · \(outcome.minutes) min")
                .font(PagewormFont.rounded(.headline))
            if let speed = outcome.pagesPerHour {
                Text(String(format: "%.0f pages an hour", speed))
                    .foregroundStyle(Color.pwInkSoft)
            }
            if outcome.qualified {
                Text(screenTime.isAuthorized
                    ? "Apps are unlocked for \(max(screenTime.unlockMinutes, UnlockPolicy.minimumWindowMinutes)) minutes. Streak: \(outcome.streak)."
                    : "That counts. Streak: \(outcome.streak). Shields start once Screen Time is approved.")
                    .multilineTextAlignment(.center)
            } else {
                Text("Five minutes and a page unlock the door. This one is saved, but the shield stays.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.pwInkSoft)
            }
            if outcome.finishedBook {
                Text("You finished it. Inky felt that.")
                    .font(PagewormFont.rounded(.headline, weight: .semibold))
            }
            Button("Done") { dismiss() }
                .buttonStyle(InkButtonStyle())
        }
    }

    private var readableBooks: [Book] {
        books.filter { $0.shelf != .read && $0.finishedAt == nil }
    }

    private var selectedBook: Book? {
        books.first { $0.bookID == bookID }
    }

    private func restore() {
        if let current = books.first(where: \.isCurrent) ?? readableBooks.first {
            bookID = current.id
            startPage = current.currentPage
            endPage = current.currentPage
        }
        if let snapshot = AppGroupStore.load()?.reading, startedAt == nil, outcome == nil {
            bookID = snapshot.bookID
            startPage = snapshot.startPage
            endPage = snapshot.startPage
            startedAt = snapshot.startedAt
        }
    }

    private func start() {
        guard let book = selectedBook else { return }
        for other in books where other.bookID != book.bookID {
            other.isCurrent = false
        }
        book.isCurrent = true
        if book.shelf == .toRead { book.shelf = .currentlyReading }
        let now = Date()
        startedAt = now
        endPage = startPage
        let snapshot = ReadingSnapshot(bookID: book.bookID, bookTitle: book.title, startPage: startPage, startedAt: now)
        SnapshotSync.write(context: context, isPremium: subscriptions.isPremium, reading: .set(snapshot))
        if Access.allows(.liveActivity, isPremium: subscriptions.isPremium) {
            let mood = InkyEvolution.mood(lastReadDay: Date(), now: now, calendar: .current)
            LiveActivityController.start(title: book.title, startedAt: now, startPage: startPage, mood: mood.rawValue)
        }
        try? context.save()
    }

    private func stop() {
        guard let book = selectedBook, let startedAt else { return }
        guard endPage >= startPage else {
            pageError = "The end page needs to be the start page or later."
            return
        }
        pageError = nil
        let result = SessionFinisher.finish(
            context: context,
            book: book,
            startedAt: startedAt,
            endedAt: Date(),
            startPage: startPage,
            endPage: endPage,
            isPremium: subscriptions.isPremium,
            screenTime: screenTime
        )
        self.startedAt = nil
        outcome = result
        LiveActivityController.end()
        SnapshotSync.write(context: context, isPremium: subscriptions.isPremium, reading: .set(nil))
    }

    private func elapsed(since start: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
