import XCTest
@testable import PagewormCore

final class ForecastTests: XCTestCase {
    private var calendar: Calendar { PagewormCalendar.utc() }

    func testFinishForecastAndFasterScrollSwap() {
        let now = date(2024, 6, 1, 15)
        let forecast = ForecastMath.forecast(
            currentPage: 0,
            pageCount: 320,
            pagesPerHour: 40,
            minutesPerDay: 40,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(forecast?.remainingPages, 320)
        XCTAssertEqual(forecast?.hoursRemaining ?? 0, 8, accuracy: 0.001)
        XCTAssertEqual(forecast?.sessionsRemaining, 20)
        XCTAssertEqual(forecast?.finishDate, calendar.startOfDay(for: date(2024, 6, 12, 0)))
        XCTAssertEqual(forecast?.fasterFinishDate, calendar.startOfDay(for: date(2024, 6, 5, 0)))
        XCTAssertEqual(forecast?.daysSaved, 7)
        XCTAssertNil(ForecastMath.forecast(currentPage: 320, pageCount: 320, pagesPerHour: 40, minutesPerDay: 20, now: now, calendar: calendar))
    }

    func testReadingSpeedUsesTotalsAndADefault() {
        XCTAssertEqual(ReadingStats.aggregatePagesPerHour([]), ReadingStats.defaultPagesPerHour)
        let speed = ReadingStats.aggregatePagesPerHour([
            SpeedSample(pages: 20, minutes: 30),
            SpeedSample(pages: 0, minutes: 10),
            SpeedSample(pages: 10, minutes: 15)
        ])
        XCTAssertEqual(speed, 40, accuracy: 0.001)
    }

    func testShelfCountdownAndChapters() {
        let countdown = TBRMath.countdown(
            books: [
                ShelfBook(pageCount: 300, currentPage: 0, shelf: .toRead),
                ShelfBook(pageCount: 100, currentPage: 40, shelf: .currentlyReading),
                ShelfBook(pageCount: 50, currentPage: 50, shelf: .read),
                ShelfBook(pageCount: nil, currentPage: 0, shelf: .toRead)
            ],
            pagesPerHour: 40,
            minutesPerDay: 60
        )
        XCTAssertEqual(countdown.totalPages, 360)
        XCTAssertEqual(countdown.knownBooks, 2)
        XCTAssertEqual(countdown.unknownPageBooks, 1)
        XCTAssertEqual(countdown.days, 9)

        XCTAssertEqual(ChapterProgress.pagesUntilNextChapter(currentPage: 42, pageCount: 300, pagesPerChapter: 15), 3)
        XCTAssertEqual(ChapterProgress.pagesUntilNextChapter(currentPage: 45, pageCount: 300, pagesPerChapter: 15), 15)
        XCTAssertEqual(ChapterProgress.pagesUntilNextChapter(currentPage: 310, pageCount: 312, pagesPerChapter: 15), 2)
        XCTAssertEqual(ChapterProgress.pagesUntilNextChapter(currentPage: 312, pageCount: 312, pagesPerChapter: 15), 0)
    }

    func testShockMathAndScrollSummary() {
        XCTAssertEqual(AttentionMath.yearsOnPhone(dailyHours: 4, age: 25), 4 * 55 / 24, accuracy: 0.0001)
        XCTAssertEqual(AttentionMath.booksYouCouldRead(dailyHours: 4, age: 25), 10044)
        XCTAssertEqual(AttentionMath.yearsOnPhone(dailyHours: 3, age: 90), 0)
        XCTAssertEqual(AttentionMath.booksYouCouldRead(dailyHours: -2, age: 30), 0)

        XCTAssertEqual(ScrollConversion.pages(from: 4 * 3600, pagesPerHour: 29.5), 118)
        XCTAssertEqual(
            ScrollConversion.summary(duration: 4 * 3600, pagesPerHour: 29.5, sourceName: "TikTok"),
            "4h back from TikTok is 118 pages"
        )
        XCTAssertEqual(ScrollConversion.format(hours: 0.5), "30m")
        XCTAssertEqual(ScrollConversion.summary(duration: 0, pagesPerHour: 40, sourceName: nil), "0m back is 0 pages")
    }

    func testInkyGrowthMoodAndGate() {
        XCTAssertEqual(InkyStage.stage(streak: 0, finishedBooks: 0), .bookling)
        XCTAssertEqual(InkyStage.stage(streak: 2, finishedBooks: 1), .pageNibbler)
        XCTAssertEqual(InkyStage.stage(streak: 7, finishedBooks: 0), .chapterChomper)
        XCTAssertEqual(InkyStage.stage(streak: 0, finishedBooks: 8), .novelNommer)
        XCTAssertEqual(InkyStage.stage(streak: 60, finishedBooks: 0), .libraryLegend)
        XCTAssertEqual(InkyStage.visibleStage(streak: 60, finishedBooks: 20, isPremium: false), .bookling)
        XCTAssertEqual(InkyStage.visibleStage(streak: 7, finishedBooks: 3, isPremium: true), .chapterChomper)

        let now = date(2024, 6, 1, 15)
        XCTAssertEqual(
            InkyMoodDecider.mood(now: now, lastSessionEndedAt: now.addingTimeInterval(-60), readToday: true, justFinishedBook: false, calendar: calendar),
            .sleepy
        )
        XCTAssertEqual(
            InkyMoodDecider.mood(now: now, lastSessionEndedAt: now.addingTimeInterval(-40 * 3600), readToday: false, justFinishedBook: false, calendar: calendar),
            .missingYou
        )
        XCTAssertEqual(
            InkyMoodDecider.mood(now: now, lastSessionEndedAt: now.addingTimeInterval(-5 * 3600), readToday: true, justFinishedBook: true, calendar: calendar),
            .cheering
        )
        let late = date(2024, 6, 1, 23, 30)
        XCTAssertEqual(
            InkyMoodDecider.mood(now: late, lastSessionEndedAt: nil, readToday: false, justFinishedBook: false, calendar: calendar),
            .sleepy
        )

        let free = FeatureGate(isPremium: false)
        XCTAssertFalse(free.allows(.storyGraphImport))
        XCTAssertTrue(free.withinSelectionLimit(appCount: 1, webCount: 0, categoryCount: 0))
        XCTAssertFalse(free.withinSelectionLimit(appCount: 2, webCount: 0, categoryCount: 0))
        XCTAssertFalse(free.withinSelectionLimit(appCount: 0, webCount: 0, categoryCount: 1))
        XCTAssertTrue(FeatureGate(isPremium: true).withinSelectionLimit(appCount: 4, webCount: 1, categoryCount: 2))
        XCTAssertFalse(FeatureGate(isPremium: true).withinSelectionLimit(appCount: 51, webCount: 0, categoryCount: 0))
    }

    func testPlaybackPledgeAndSnapshotRoundTrip() throws {
        let answers = QuizAnswers(
            name: "Ada",
            why: "I miss reading",
            dailyPhoneHours: 4.5,
            distractingApps: ["Instagram", "TikTok", "YouTube"],
            dailyReadingMinutes: 20,
            age: 31
        )
        let playback = OnboardingCopy.playback(answers)
        XCTAssertTrue(playback.contains("I'm Ada."))
        XCTAssertTrue(playback.contains("I miss reading"))
        XCTAssertTrue(playback.contains("4.5 hours"))
        XCTAssertTrue(playback.contains("Instagram, TikTok, and YouTube"))
        XCTAssertTrue(playback.contains("20 minutes"))
        XCTAssertTrue(OnboardingCopy.pledge(name: "Ada").contains("I, Ada,"))
        XCTAssertEqual(OnboardingCopy.scrollSwapName(apps: ["TikTok", "Instagram"]), "Instagram")
        XCTAssertTrue(OnboardingCopy.shockBooksLine(books: 10044, apps: ["TikTok"]).contains("10,044"))

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = ShieldSnapshot(
            bookTitle: "Piranesi",
            pagesToNextChapter: 12,
            focusAppName: "TikTok",
            inkyStage: .pageNibbler,
            inkyMood: .happy,
            streak: 4,
            isPremium: true,
            pagesPerHour: 36,
            blockingEnabled: true,
            strictMode: true,
            unlock: UnlockWindow(startsAt: now, endsAt: now.addingTimeInterval(900), source: .emergency),
            schedule: .evenings,
            updatedAt: now
        )
        let defaults = UserDefaults(suiteName: "pageworm.tests.\(UUID().uuidString)")!
        SharedStore.setSnapshot(snapshot, in: defaults)
        XCTAssertEqual(SharedStore.snapshot(in: defaults), snapshot)

        let session = ActiveSessionState(bookID: "abc", bookTitle: "Piranesi", startPage: 20, startedAt: now)
        SharedStore.setActiveSession(session, in: defaults)
        XCTAssertEqual(SharedStore.activeSession(in: defaults), session)
        SharedStore.setPendingRead(true, in: defaults)
        XCTAssertTrue(SharedStore.consumePendingRead(in: defaults))
        XCTAssertFalse(SharedStore.consumePendingRead(in: defaults))
        SharedStore.setSelectionData(Data([1, 2, 3]), in: defaults)
        XCTAssertEqual(SharedStore.selectionData(in: defaults), Data([1, 2, 3]))
    }

    func testMetadataParsers() throws {
        let openLibrary = """
        {"number_of_pages": 304, "covers": [12345], "title": "Oh"}
        """.data(using: .utf8)!
        let parsed = try XCTUnwrap(OpenLibraryParser.parseISBNPayload(openLibrary))
        XCTAssertEqual(parsed.pageCount, 304)
        XCTAssertEqual(parsed.coverURL, "https://covers.openlibrary.org/b/id/12345-L.jpg")

        let search = """
        {"docs":[{"number_of_pages_median":245,"cover_i":9}]}
        """.data(using: .utf8)!
        XCTAssertEqual(OpenLibraryParser.parseSearchPayload(search)?.pageCount, 245)
        XCTAssertNil(OpenLibraryParser.parseISBNPayload("{\"error\":\"notfound\"}".data(using: .utf8)!))

        let google = """
        {"items":[{"volumeInfo":{"pageCount":387,"imageLinks":{"thumbnail":"http://books.google.com/x?zoom=1&edge=curl"}}}]}
        """.data(using: .utf8)!
        let googleParsed = try XCTUnwrap(GoogleBooksParser.parse(google))
        XCTAssertEqual(googleParsed.pageCount, 387)
        XCTAssertEqual(googleParsed.coverURL, "https://books.google.com/x?zoom=2")
        let merged = ParsedBookMetadata(pageCount: nil, coverURL: "https://covers.example/a.jpg", source: "openlibrary")
            .fillingGaps(from: googleParsed)
        XCTAssertEqual(merged.pageCount, 387)
        XCTAssertEqual(merged.coverURL, "https://covers.example/a.jpg")
        XCTAssertEqual(merged.source, "openlibrary+googlebooks")
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var parts = DateComponents()
        parts.calendar = calendar
        parts.timeZone = calendar.timeZone
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = hour
        parts.minute = minute
        return calendar.date(from: parts)!
    }
}
