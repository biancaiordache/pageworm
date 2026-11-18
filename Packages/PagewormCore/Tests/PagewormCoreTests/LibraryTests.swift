import XCTest
@testable import PagewormCore

final class LibraryTests: XCTestCase {
    func testISBNNormalizerHandlesGoodreadsFormulasAndBlanks() {
        XCTAssertEqual(ISBNNormalizer.normalize("=\"9780061120081\""), "9780061120081")
        XCTAssertEqual(ISBNNormalizer.normalize("=\"\""), nil)
        XCTAssertEqual(ISBNNormalizer.normalize(""), nil)
        XCTAssertEqual(ISBNNormalizer.normalize(nil), nil)
        XCTAssertEqual(ISBNNormalizer.normalize(" 978-0-06-112008-1 "), "9780061120081")
        XCTAssertEqual(ISBNNormalizer.normalize("0807083690"), "0807083690")
        XCTAssertNil(ISBNNormalizer.normalize("storygraph-uid-123"))
        XCTAssertNil(ISBNNormalizer.normalize("978X061120081"))
    }

    func testEscapedQuotesInsideAField() throws {
        let csv = #"""
        Title,Exclusive Shelf,My Review
        "Kindred, the novel","to-read","She said, ""read me"""
        """#
        let imported = LibraryCSVParser.parse(csv, calendar: utcCalendar())
        let book = try XCTUnwrap(imported.books.first)
        XCTAssertEqual(book.title, "Kindred, the novel")
        XCTAssertEqual(book.shelf, .toRead)
    }

    func testGoodreadsExportWithQuotedCommasNewlinesAndBlankISBN() throws {
        let csv = """
        Book Id,Title,Author,Author l-f,Additional Authors,ISBN,ISBN13,My Rating,Average Rating,Publisher,Binding,Number of Pages,Year Published,Original Publication Year,Date Read,Date Added,Bookshelves,Bookshelves with positions,Exclusive Shelf,My Review,Spoiler,Private Notes,Read Count,Owned Copies
        1,"Kindred, the novel",Octavia E. Butler,Butler Octavia,,"",="9780807083697",5,4.30,Beacon,Paperback,264,2003,1979,,2020/01/02,to-read,,"to-read",Loved it,,,1,0
        2,Blank ISBN,Someone,,,,="",0,0,None,Paperback,,,,,2020/03/04,,,to-read,,,,0,0
        3,"Line
        Break Title",Ada Lovelace,Lovelace Ada,,,="",0,0,Press,Paperback,120,,,,2020/05/06,,,currently-reading,,,,0,0
        4,Already Read,Ursula K. Le Guin,Le Guin Ursula,,,="9780441478125",4,4.1,Ace,Paperback,304,1969,1969,2021/01/01,2020/01/01,read,,read,,,,1,1
        """
        let imported = LibraryCSVParser.parse(csv, calendar: utcCalendar())
        XCTAssertEqual(imported.source, .goodreads)
        XCTAssertEqual(imported.books.count, 4)
        XCTAssertEqual(imported.skipped, 0)

        let kindred = try XCTUnwrap(imported.books.first)
        XCTAssertEqual(kindred.title, "Kindred, the novel")
        XCTAssertEqual(kindred.isbn, "9780807083697")
        XCTAssertEqual(kindred.pageCount, 264)
        XCTAssertEqual(kindred.shelf, .toRead)
        XCTAssertEqual(kindred.rating, 5)
        XCTAssertEqual(kindred.dateAdded, date(2020, 1, 2))

        XCTAssertNil(imported.books[1].isbn)
        XCTAssertEqual(imported.books[1].shelf, .toRead)
        XCTAssertEqual(imported.books[1].dateAdded, date(2020, 3, 4))

        XCTAssertTrue(imported.books[2].title.contains("Line"))
        XCTAssertTrue(imported.books[2].title.contains("Break Title"))
        XCTAssertEqual(imported.books[2].shelf, .currentlyReading)
        XCTAssertEqual(imported.books[2].pageCount, 120)

        XCTAssertEqual(imported.books[3].shelf, .read)
        XCTAssertEqual(imported.books[3].isbn, "9780441478125")
        XCTAssertEqual(imported.count(on: .toRead), 2)
        XCTAssertEqual(imported.count(on: .currentlyReading), 1)
    }

    func testStoryGraphExportAndShelfNames() {
        let csv = """
        Title,Authors,Contributors,ISBN/UID,Format,Read Status,Date Added,Last Date Read,Dates Read,Read Count,Star Rating,Review,Tags,Owned?
        Always Coming Home,"Ursula K. Le Guin, Todd Barton",,9780520227354,paperback,to-read,2021/05/10,,,0,,,"",No
        Subprime Attention Crisis,Tim Hwang,,0374538654,paperback,read,10/05/2021,2021/06/01,2021/05/20-2021/06/01,1,3.75,"A sharp, short book",,No
        Piranesi,Susanna Clarke,,not-an-isbn,ebook,currently reading,2021/07/01,,,0,0,,,No
        DNF Novel,Author,,9780000000002,paperback,did-not-finish,2021/08/15,,,1,,,,No
        """
        let imported = LibraryCSVParser.parse(csv, calendar: utcCalendar())
        XCTAssertEqual(imported.source, .storyGraph)
        XCTAssertEqual(imported.books.count, 4)
        XCTAssertEqual(imported.books[0].authors, "Ursula K. Le Guin, Todd Barton")
        XCTAssertEqual(imported.books[0].isbn, "9780520227354")
        XCTAssertEqual(imported.books[0].shelf, .toRead)
        XCTAssertEqual(imported.books[0].dateAdded, date(2021, 5, 10))
        XCTAssertNil(imported.books[0].pageCount)

        XCTAssertEqual(imported.books[1].isbn, "0374538654")
        XCTAssertEqual(imported.books[1].shelf, .read)
        XCTAssertEqual(imported.books[1].rating, 3.75)
        XCTAssertEqual(imported.books[1].dateAdded, date(2021, 5, 10))

        XCTAssertNil(imported.books[2].isbn)
        XCTAssertEqual(imported.books[2].shelf, .currentlyReading)
        XCTAssertEqual(imported.books[3].shelf, .didNotFinish)
    }

    func testSemicolonDelimiterAndSkippedBlankTitle() {
        let csv = "Title;Author;Exclusive Shelf\n;Nobody;to-read\nPiranesi;Susanna Clarke;currently-reading\n"
        let imported = LibraryCSVParser.parse(csv, calendar: utcCalendar())
        XCTAssertEqual(imported.source, .goodreads)
        XCTAssertEqual(imported.books.count, 1)
        XCTAssertEqual(imported.skipped, 1)
        XCTAssertEqual(imported.books[0].title, "Piranesi")
        XCTAssertEqual(imported.books[0].shelf, .currentlyReading)
    }

    func testDateParsingAmbiguityFollowsSource() {
        let calendar = utcCalendar()
        XCTAssertEqual(DateParsing.parse("2021/05/10", preferDayFirst: true, calendar: calendar), date(2021, 5, 10))
        XCTAssertEqual(DateParsing.parse("27/08/2023", preferDayFirst: false, calendar: calendar), date(2023, 8, 27))
        XCTAssertEqual(DateParsing.parse("10/09/2023", preferDayFirst: true, calendar: calendar), date(2023, 9, 10))
        XCTAssertEqual(DateParsing.parse("10/09/2023", preferDayFirst: false, calendar: calendar), date(2023, 10, 9))
        XCTAssertNil(DateParsing.parse("", preferDayFirst: false, calendar: calendar))
    }
}
