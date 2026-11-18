import ActivityKit
import FamilyControls
import Foundation
import PagewormCore
import SwiftData
import WidgetKit

enum AppTab: Hashable {
    case home, library, insights, settings
}

@MainActor
final class PagewormModel: ObservableObject {
    private let context: ModelContext
    let purchases = PurchaseManager()
    let notifications = InkyNotifications()
    private let metadata = MetadataClient()

    @Published var profile: UserProfile
    @Published var banner: String?
    @Published var tab: AppTab = .home
    @Published var showPaywall = false
    @Published var readingBookID: UUID?
    @Published var activeSession: ActiveSessionState?
    @Published var screenTimeApproved = false
    @Published var finishedCelebration: Book?

    init(context: ModelContext) {
        self.context = context
        let existing = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        if let profile = existing.first {
            self.profile = profile
        } else {
            let profile = UserProfile()
            context.insert(profile)
            try? context.save()
            self.profile = profile
        }
    }

    func start() {
        notifications.configure()
        notifications.onOpenRead = { [weak self] in
            self?.openReadingFromOutside()
        }
        purchases.onPremiumChange = { [weak self] premium in
            guard let self else { return }
            self.profile.isPremium = premium
            self.save()
            self.sync()
        }
        purchases.start()
        profile.isPremium = purchases.isPremium || profile.isPremium
        activeSession = SharedStore.activeSession(in: AppGroupDefaults.suite())
        refreshAuthorization()
        sync()
        if SharedStore.consumePendingRead(in: AppGroupDefaults.suite()) {
            openReadingFromOutside()
        }
    }

    func refreshAuthorization() {
        screenTimeApproved = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    func sceneBecameActive() {
        refreshAuthorization()
        sync()
    }

    func requestScreenTime() async -> String? {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refreshAuthorization()
            sync()
            return screenTimeApproved ? nil : "Screen Time isn't approved yet."
        } catch {
            refreshAuthorization()
            return "Apple didn't grant Screen Time. On the Simulator this always fails. You can keep reading and try again on your iPhone."
        }
    }

    func progress(books: [Book], sessions: [ReadingSessionRecord]) -> ReadingProgress {
        ReadingProgress(books: books, sessions: sessions, profile: profile, now: Date())
    }

    func finishOnboarding(_ answers: QuizAnswers, signed: Bool) {
        profile.name = answers.name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.whyHere = answers.why
        profile.dailyPhoneHours = answers.dailyPhoneHours
        profile.distractingApps = answers.distractingApps
        profile.dailyReadingMinutes = answers.dailyReadingMinutes
        profile.age = answers.age
        profile.pledgeSignedAt = signed ? Date() : profile.pledgeSignedAt
        profile.onboardingComplete = true
        if !profile.blockingEnabled {
            profile.schedule = .allDay
        }
        save()
        sync()
    }

    func updateSchedule(_ schedule: BlockSchedule) {
        profile.schedule = schedule
        save()
        sync()
    }

    func updateSelection(_ selection: FamilyActivitySelection, enforceLimit: Bool) -> String? {
        let gate = FeatureGate(isPremium: profile.isPremium)
        let apps = selection.applicationTokens.count
        let webs = selection.webDomainTokens.count
        let categories = selection.categoryTokens.count
        if enforceLimit, !gate.withinSelectionLimit(appCount: apps, webCount: webs, categoryCount: categories) {
            if apps > FeatureGate.appleTokenLimit || webs > FeatureGate.appleTokenLimit || categories > FeatureGate.appleTokenLimit {
                return "Apple shields up to 50 at a time. Remove a few."
            }
            return "The free plan blocks one app. Categories and extra apps are part of Plus."
        }
        SelectionStore.save(selection)
        sync()
        return nil
    }

    func setStrict(_ enabled: Bool) -> String? {
        if enabled, !profile.isPremium {
            showPaywall = true
            return "Strict mode is part of Plus."
        }
        profile.strictMode = enabled
        save()
        sync()
        return nil
    }

    func setUnlockMinutes(_ minutes: Int) -> String? {
        if !profile.isPremium, minutes != UnlockPolicy.defaultMinutes {
            showPaywall = true
            return "Choosing the unlock length is part of Plus."
        }
        profile.unlockMinutes = UnlockPolicy.normalizedMinutes(minutes)
        save()
        sync()
        return nil
    }

    func setNotifications(enabled: Bool) async {
        if enabled {
            let granted = await notifications.request()
            profile.notificationsEnabled = granted
            if !granted {
                banner = "Notifications stay off until you allow them in Settings."
            }
        } else {
            profile.notificationsEnabled = false
        }
        save()
        sync()
    }

    func setBlockingEnabled(_ enabled: Bool) -> String? {
        if !enabled, profile.strictMode {
            return "Strict mode is on. Hold to turn strict mode off before you open the door for good."
        }
        profile.blockingEnabled = enabled
        save()
        sync()
        return nil
    }

    func redeemEmergency() -> String? {
        guard profile.isPremium else {
            showPaywall = true
            return "The weekly emergency unlock is part of Plus."
        }
        guard profile.strictMode else { return "Turn on strict mode if you want the emergency held in reserve." }
        let calendar = PagewormCalendar.make()
        guard EmergencyUnlockPolicy.canRedeem(lastRedeemedAt: profile.lastEmergencyUnlockAt, now: Date(), calendar: calendar) else {
            return "You've used this week's emergency. Inky believes in you."
        }
        profile.lastEmergencyUnlockAt = Date()
        save()
        grantUnlock(source: .emergency)
        return nil
    }

    func importFile(at url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            banner = "I couldn't read that file."
            return
        }
        let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        let parsed: (format: ImportFormat, books: [ImportedBook])
        do {
            parsed = try LibraryImporter.detectAndImport(text)
        } catch {
            banner = importMessage(error)
            return
        }
        if parsed.format == .storyGraph, !profile.isPremium {
            showPaywall = true
            banner = "StoryGraph import is part of Plus. Goodreads imports stay free."
            return
        }
        let existing = (try? context.fetch(FetchDescriptor<Book>())) ?? []
        var inserted: [Book] = []
        for item in parsed.books where item.shelf == .toRead || item.shelf == .currentlyReading || item.shelf == .read {
            if let match = existing.first(where: { sameBook($0, item) }) ?? inserted.first(where: { sameBook($0, item) }) {
                if match.pageCount == nil { match.pageCount = item.pageCount }
                if match.shelf == .toRead, item.shelf == .currentlyReading { match.shelf = .currentlyReading }
                continue
            }
            let book = Book(
                title: item.title,
                author: item.author,
                isbn: item.isbn,
                pageCount: item.pageCount,
                shelf: item.shelf,
                source: item.source.rawValue,
                dateAdded: item.dateAdded ?? Date(),
                rating: item.rating
            )
            context.insert(book)
            inserted.append(book)
        }
        save()
        banner = inserted.isEmpty ? "Those books were already on the shelf." : "I shelved \(inserted.count) books."
        let pending = inserted.filter { $0.coverURL == nil || $0.pageCount == nil }
        Task { await enrich(pending) }
    }

    func addBook(title: String, author: String, pages: Int?, shelf: ReadingShelf) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            banner = "A book needs a title."
            return
        }
        let book = Book(
            title: trimmed,
            author: author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown" : author,
            pageCount: pages,
            shelf: shelf,
            source: "manual"
        )
        if shelf == .currentlyReading { clearCurrent(except: book.id) }
        context.insert(book)
        save()
        Task { await enrich([book]) }
    }

    func update(book: Book, title: String, author: String, pages: Int?, currentPage: Int, shelf: ReadingShelf) {
        book.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        book.author = author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown" : author
        book.pageCount = pages
        book.currentPage = max(0, currentPage)
        book.shelf = shelf
        if shelf == .read, book.finishedAt == nil {
            book.finishedAt = Date()
            book.isCurrent = false
        }
        if shelf == .currentlyReading {
            clearCurrent(except: book.id)
            book.isCurrent = true
        }
        save()
        sync()
    }

    func delete(_ book: Book) {
        if readingBookID == book.id { readingBookID = nil }
        context.delete(book)
        save()
        sync()
    }

    func makeCurrent(_ book: Book) {
        clearCurrent(except: book.id)
        book.isCurrent = true
        if book.shelf == .toRead { book.shelf = .currentlyReading }
        save()
        sync()
    }

    func beginReading(_ book: Book) {
        makeCurrent(book)
        let state = ActiveSessionState(
            bookID: book.id.uuidString,
            bookTitle: book.title,
            startPage: book.currentPage,
            startedAt: Date()
        )
        activeSession = state
        SharedStore.setActiveSession(state, in: AppGroupDefaults.suite())
        readingBookID = book.id
        startLiveActivity(state, stage: currentStage(), mood: currentMood())
        sync()
    }

    func resumeIfNeeded(books: [Book]) {
        guard readingBookID == nil, let activeSession else { return }
        readingBookID = UUID(uuidString: activeSession.bookID)
        if readingBookID == nil {
            self.activeSession = nil
            SharedStore.setActiveSession(nil, in: AppGroupDefaults.suite())
        } else if books.contains(where: { $0.id.uuidString == activeSession.bookID }) == false {
            self.activeSession = nil
            SharedStore.setActiveSession(nil, in: AppGroupDefaults.suite())
            readingBookID = nil
        }
    }

    func stopReading(book: Book, endPage: Int) -> String? {
        guard let activeSession, activeSession.bookID == book.id.uuidString else {
            return "There's no timer running for this book."
        }
        let draft = SessionDraft(
            startPage: activeSession.startPage,
            endPage: endPage,
            startedAt: activeSession.startedAt,
            endedAt: Date()
        )
        let result: SessionResult
        do {
            result = try SessionMath.result(draft)
        } catch {
            return "The ending page needs to be the start page or later."
        }
        let record = ReadingSessionRecord(
            bookID: book.id,
            bookTitle: book.title,
            startedAt: activeSession.startedAt,
            endedAt: draft.endedAt,
            startPage: activeSession.startPage,
            endPage: endPage,
            pages: result.pages,
            minutes: result.minutes
        )
        context.insert(record)
        book.currentPage = endPage
        var finished = false
        if let pageCount = book.pageCount, endPage >= pageCount {
            book.shelf = .read
            book.finishedAt = Date()
            book.isCurrent = false
            finished = true
            finishedCelebration = book
        }
        self.activeSession = nil
        readingBookID = nil
        SharedStore.setActiveSession(nil, in: AppGroupDefaults.suite())
        endLiveActivity()
        save()
        if result.grantsUnlock {
            grantUnlock(source: .readingSession)
            banner = "\(profile.unlockMinutes) minutes. The door is open, and it will shut itself."
        } else {
            sync()
            banner = "I saved the session. A minute or more opens the door."
        }
        if finished {
            banner = "You finished \(book.title)."
        }
        return nil
    }

    func openReadingFromOutside() {
        let books = (try? context.fetch(FetchDescriptor<Book>())) ?? []
        if let activeSession, let id = UUID(uuidString: activeSession.bookID), books.contains(where: { $0.id == id }) {
            readingBookID = id
            return
        }
        let progress = progress(books: books, sessions: (try? context.fetch(FetchDescriptor<ReadingSessionRecord>())) ?? [])
        if let book = progress.currentBook {
            tab = .home
            readingBookID = book.id
        } else {
            tab = .library
            banner = "Add a book, then I'll start the timer."
        }
    }

    func handle(url: URL) {
        guard url.scheme == "pageworm" else { return }
        switch url.host {
        case "read": openReadingFromOutside()
        case "library": tab = .library
        case "paywall": showPaywall = true
        default: tab = .home
        }
    }

    func dismissCelebration() {
        finishedCelebration = nil
    }

    private func grantUnlock(source: UnlockSource) {
        let window = UnlockPolicy.makeWindow(from: Date(), minutes: profile.unlockMinutes, source: source)
        notifications.scheduleUnlockEnding(at: window.endsAt)
        sync(overrideUnlock: window)
    }

    private func sync(overrideUnlock: UnlockWindow? = nil) {
        let defaults = AppGroupDefaults.suite()
        let previous = SharedStore.snapshot(in: defaults)
        let unlock: UnlockWindow?
        if let overrideUnlock {
            unlock = overrideUnlock
        } else if let existing = previous.unlock, existing.contains(Date()) {
            unlock = existing
        } else {
            unlock = nil
        }
        let books = (try? context.fetch(FetchDescriptor<Book>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<ReadingSessionRecord>())) ?? []
        let reading = progress(books: books, sessions: sessions)
        let book = reading.currentBook
        let pagesLeft = ChapterProgress.pagesUntilNextChapter(
            currentPage: book?.currentPage ?? 0,
            pageCount: book?.pageCount,
            pagesPerChapter: profile.pagesPerChapter
        )
        let snapshot = ShieldSnapshot(
            bookTitle: book?.title ?? "",
            pagesToNextChapter: pagesLeft,
            focusAppName: OnboardingCopy.scrollSwapName(apps: profile.distractingApps),
            inkyStage: reading.stage,
            inkyMood: reading.mood,
            streak: reading.streak.currentStreak,
            isPremium: profile.isPremium,
            pagesPerHour: reading.pagesPerHour,
            blockingEnabled: profile.blockingEnabled && profile.onboardingComplete,
            strictMode: profile.strictMode,
            unlock: unlock,
            schedule: profile.schedule,
            updatedAt: Date()
        )
        SharedStore.setSnapshot(snapshot, in: defaults)
        ShieldRuntime.reevaluate(defaults: defaults)
        if screenTimeApproved {
            ScheduleMonitor.sync(schedule: snapshot.blockingEnabled ? snapshot.schedule : BlockSchedule(enabled: false, startMinutes: 0, endMinutes: 60, weekdays: []), unlock: unlock)
        }
        WidgetCenter.shared.reloadAllTimelines()
        notifications.reschedule(
            name: profile.name,
            notificationsEnabled: profile.notificationsEnabled,
            readToday: reading.streak.readToday,
            missing: reading.mood == .missingYou
        )
    }

    private func enrich(_ books: [Book]) async {
        for book in books where book.coverURL == nil || book.pageCount == nil {
            guard let metadata = await metadata.enrich(isbn: book.isbn, title: book.title, author: book.author) else { continue }
            if book.pageCount == nil { book.pageCount = metadata.pageCount }
            if book.coverURL == nil { book.coverURL = metadata.coverURL }
            save()
        }
        sync()
    }

    private func sameBook(_ book: Book, _ item: ImportedBook) -> Bool {
        if let isbn = book.isbn, let other = item.isbn, isbn == other { return true }
        return book.title.compare(item.title, options: .caseInsensitive) == .orderedSame
            && book.author.compare(item.author, options: .caseInsensitive) == .orderedSame
    }

    private func sameBook(_ book: Book, _ other: Book) -> Bool {
        if let isbn = book.isbn, let otherISBN = other.isbn, isbn == otherISBN { return true }
        return book.title.compare(other.title, options: .caseInsensitive) == .orderedSame
            && book.author.compare(other.author, options: .caseInsensitive) == .orderedSame
    }

    private func clearCurrent(except id: UUID) {
        let books = (try? context.fetch(FetchDescriptor<Book>())) ?? []
        for book in books where book.id != id {
            book.isCurrent = false
        }
    }

    private func save() {
        try? context.save()
        objectWillChange.send()
    }

    private func importMessage(_ error: Error) -> String {
        switch error {
        case LibraryImportError.empty:
            return "That file was empty."
        case LibraryImportError.unrecognizedFormat:
            return "I know Goodreads and StoryGraph exports. This file wasn't either."
        case LibraryImportError.missingColumns(_, let columns):
            return "The export is missing \(columns.joined(separator: ", "))."
        case CSVError.unmatchedQuote:
            return "A quote in that CSV never closed."
        default:
            return "I couldn't read that export."
        }
    }

    private func currentStage() -> InkyStage {
        let books = (try? context.fetch(FetchDescriptor<Book>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<ReadingSessionRecord>())) ?? []
        return progress(books: books, sessions: sessions).stage
    }

    private func currentMood() -> InkyMood {
        let books = (try? context.fetch(FetchDescriptor<Book>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<ReadingSessionRecord>())) ?? []
        return progress(books: books, sessions: sessions).mood
    }

    private func startLiveActivity(_ session: ActiveSessionState, stage: InkyStage, mood: InkyMood) {
        guard profile.isPremium else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = ReadingActivityAttributes(bookTitle: session.bookTitle, startedAt: session.startedAt)
        let state = ReadingActivityAttributes.ContentState(
            startedAt: session.startedAt,
            startPage: session.startPage,
            stageRaw: stage.rawValue,
            moodRaw: mood.rawValue
        )
        _ = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )
    }

    private func endLiveActivity() {
        Task {
            for activity in Activity<ReadingActivityAttributes>.activities {
                await activity.end(activity.content, dismissalPolicy: .immediate)
            }
        }
    }
}
