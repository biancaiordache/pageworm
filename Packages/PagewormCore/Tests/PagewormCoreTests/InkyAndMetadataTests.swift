import XCTest
@testable import PagewormCore

final class InkyAndMetadataTests: XCTestCase {
    func testInkyStageThresholdsAndFreeTier() {
        XCTAssertEqual(InkyEvolution.stage(finishedBooks: 0, streak: 0), .sprout)
        XCTAssertEqual(InkyEvolution.stage(finishedBooks: 0, streak: 2), .sprout)
        XCTAssertEqual(InkyEvolution.stage(finishedBooks: 1, streak: 0), .bookworm)
        XCTAssertEqual(InkyEvolution.stage(finishedBooks: 0, streak: 3), .bookworm)
        XCTAssertEqual(InkyEvolution.stage(finishedBooks: 3, streak: 0), .pageEater)
        XCTAssertEqual(InkyEvolution.stage(finishedBooks: 0, streak: 7), .pageEater)
        XCTAssertEqual(InkyEvolution.stage(finishedBooks: 10, streak: 0), .scholar)
        XCTAssertEqual(InkyEvolution.stage(finishedBooks: 0, streak: 30), .scholar)
        XCTAssertEqual(InkyEvolution.stage(finishedBooks: 25, streak: 0), .legend)
        XCTAssertEqual(InkyEvolution.stage(finishedBooks: 0, streak: 100), .legend)
        XCTAssertEqual(InkyEvolution.displayedStage(finishedBooks: 25, streak: 100, isPremium: false), .sprout)
        XCTAssertEqual(InkyEvolution.displayedStage(finishedBooks: 25, streak: 100, isPremium: true), .legend)
    }

    func testMoods() {
        let calendar = utcCalendar()
        let yesterday = date(2024, 4, 1, calendar: calendar)
        XCTAssertEqual(InkyEvolution.mood(lastReadDay: nil, now: date(2024, 4, 2, 10, calendar: calendar), calendar: calendar), .sleepy)
        XCTAssertEqual(InkyEvolution.mood(lastReadDay: yesterday, now: date(2024, 4, 1, 23, calendar: calendar), calendar: calendar), .happy)
        XCTAssertEqual(InkyEvolution.mood(lastReadDay: yesterday, now: date(2024, 4, 2, 12, calendar: calendar), calendar: calendar), .happy)
        XCTAssertEqual(InkyEvolution.mood(lastReadDay: yesterday, now: date(2024, 4, 2, 20, calendar: calendar), calendar: calendar), .sleepy)
        XCTAssertEqual(InkyEvolution.mood(lastReadDay: yesterday, now: date(2024, 4, 3, 9, calendar: calendar), calendar: calendar), .missingYou)
    }

    func testPlaybackAndAccess() {
        XCTAssertEqual(
            InkyCopy.playback(name: "Maya", why: "your evenings back", dailyHours: 5, apps: ["Instagram", "TikTok"], goalMinutes: 30),
            "Maya, you want your evenings back, but Instagram and TikTok take about 5 hours a day. You'd like 30 minutes back for books."
        )
        XCTAssertEqual(
            InkyCopy.playback(name: "  ", why: "", dailyHours: 1, apps: [], goalMinutes: 10),
            "Friend, you want to read more, but your phone takes about 1 hour a day. You'd like 10 minutes back for books."
        )
        XCTAssertEqual(InkyCopy.pledge(name: "Maya"), "Maya, I'll read before I scroll.")
        XCTAssertEqual(InkyCopy.shieldSubtitle(bookTitle: "Piranesi", pagesLeft: 1), "1 page left in this chapter of Piranesi.")
        XCTAssertFalse(Access.allows(.storyGraphImport, isPremium: false))
        XCTAssertTrue(Access.allows(.storyGraphImport, isPremium: true))
        XCTAssertEqual(Access.allowedApplicationCount(selected: 4, isPremium: false), 1)
        XCTAssertTrue(Access.selectionFitsFreeTier(applicationCount: 1, categoryCount: 0, webDomainCount: 0))
        XCTAssertFalse(Access.selectionFitsFreeTier(applicationCount: 1, categoryCount: 1, webDomainCount: 0))
    }

    func testOpenLibraryAndGoogleBooksParsing() throws {
        let openLibrary = """
        {"docs":[{"title":"The Left Hand of Darkness","author_name":["Ursula K. Le Guin"],"number_of_pages_median":304,"cover_i":12345,"isbn":["9780441478125","0441478123"]}]}
        """.data(using: .utf8)!
        let open = try XCTUnwrap(OpenLibraryAPI.parseSearch(openLibrary))
        XCTAssertEqual(open.title, "The Left Hand of Darkness")
        XCTAssertEqual(open.authors, "Ursula K. Le Guin")
        XCTAssertEqual(open.pageCount, 304)
        XCTAssertEqual(open.coverURL?.absoluteString, "https://covers.openlibrary.org/b/id/12345-L.jpg")
        XCTAssertEqual(open.isbn13, "9780441478125")

        let google = """
        {"items":[{"volumeInfo":{"title":"Kindred","authors":["Octavia E. Butler"],"pageCount":264,"imageLinks":{"thumbnail":"http://books.google.com/kindred.jpg"},"industryIdentifiers":[{"type":"ISBN_13","identifier":"9780807083697"}]}}]}
        """.data(using: .utf8)!
        let parsed = try XCTUnwrap(GoogleBooksAPI.parse(google))
        XCTAssertEqual(parsed.pageCount, 264)
        XCTAssertEqual(parsed.coverURL?.absoluteString, "https://books.google.com/kindred.jpg")
        XCTAssertEqual(parsed.isbn13, "9780807083697")

        let isbnURL = try XCTUnwrap(OpenLibraryAPI.searchURL(isbn: "=\"9780807083697\"", title: "", author: ""))
        XCTAssertTrue(isbnURL.absoluteString.contains("isbn=9780807083697"))
        let titleURL = try XCTUnwrap(GoogleBooksAPI.searchURL(isbn: nil, title: "Kindred", author: "Butler"))
        XCTAssertTrue(titleURL.absoluteString.contains("intitle"))
        XCTAssertNil(GoogleBooksAPI.parse(Data("{\"items\":[]}".utf8)))
    }

    func testSnapshotRoundTrip() throws {
        let now = date(2024, 8, 1, 10)
        var state = SharedAppState.initial(now: now)
        state.userName = "Maya"
        state.reading = ReadingSnapshot(bookID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!, bookTitle: "Kindred", startPage: 12, startedAt: now)
        state.block.unlockEndsAt = now.addingTimeInterval(900)
        let decoded = try SnapshotCoding.decode(SnapshotCoding.encode(state))
        XCTAssertEqual(decoded.userName, "Maya")
        XCTAssertEqual(decoded.reading?.bookTitle, "Kindred")
        XCTAssertEqual(decoded.block.unlockEndsAt, now.addingTimeInterval(900))
        XCTAssertEqual(decoded.shield.stage, .sprout)
    }
}
