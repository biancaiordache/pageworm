import XCTest
@testable import PagewormCore

final class ImportTests: XCTestCase {
    func testISBNCleanerHandlesGoodreadsShapes() {
        XCTAssertEqual(ISBNCleaner.clean("=\"9780553383041\""), "9780553383041")
        XCTAssertEqual(ISBNCleaner.clean("=\"\""), nil)
        XCTAssertEqual(ISBNCleaner.clean(""), nil)
        XCTAssertEqual(ISBNCleaner.clean("   "), nil)
        XCTAssertEqual(ISBNCleaner.clean("\"=\"\"9780553383041\"\"\""), "9780553383041")
        XCTAssertEqual(ISBNCleaner.clean("978-0-553-38304-1"), "9780553383041")
        XCTAssertEqual(ISBNCleaner.clean("=\"055338304X\""), "055338304X")
        XCTAssertNil(ISBNCleaner.clean("n/a"))
        XCTAssertNil(ISBNCleaner.clean("=\"123\""))
        XCTAssertNil(ISBNCleaner.clean("978055338304X"))
    }

    func testQuotedCommasAndNewlinesStayInsideTheField() throws {
        let csv = """
        Book Id,Title,Author,ISBN,ISBN13,Number of Pages,Exclusive Shelf,My Review,Date Added,My Rating
        1,"Oh, Pioneers!","Willa Cather",="0553383043",="9780553383041",304,currently-reading,"She wrote, and then
        she kept going, carefully.",2024/01/02,5
        2,"Piranesi","Susanna Clarke",="",="",245,to-read,"",2024/03/01,0
        3,"Finished Book","A. Author",="9780000000002",="9780000000002",100,read,"Done",2019/01/01,4
        """
        let result = try LibraryImporter.detectAndImport(csv)
        XCTAssertEqual(result.format, .goodreads)
        XCTAssertEqual(result.books.count, 3)

        let first = result.books[0]
        XCTAssertEqual(first.title, "Oh, Pioneers!")
        XCTAssertEqual(first.author, "Willa Cather")
        XCTAssertEqual(first.isbn, "9780553383041")
        XCTAssertEqual(first.pageCount, 304)
        XCTAssertEqual(first.shelf, .currentlyReading)
        XCTAssertEqual(first.rating, 5)
        XCTAssertNotNil(first.dateAdded)

        let second = result.books[1]
        XCTAssertEqual(second.title, "Piranesi")
        XCTAssertNil(second.isbn)
        XCTAssertEqual(second.shelf, .toRead)
        XCTAssertNil(second.rating)
        XCTAssertEqual(second.pageCount, 245)

        XCTAssertEqual(result.books[2].shelf, .read)
    }

    func testStoryGraphImportAndBlankISBN() throws {
        let csv = """
        Title,Authors,ISBN/UID,Read Status,Date Added,Star Rating,Review,Pages
        "The Dispossessed","Ursula K. Le Guin","9780061054884","currently-reading","2024-05-01","5","A long review, with commas","387"
        "Kindred","Octavia E. Butler","","to-read","2024-06-01","","","264"
        "Paused One","Someone","9780000000003","paused","2024-07-01","3","line
        break","120"
        """
        let result = try LibraryImporter.detectAndImport(csv)
        XCTAssertEqual(result.format, .storyGraph)
        XCTAssertEqual(result.books.map(\.title), ["The Dispossessed", "Kindred", "Paused One"])
        XCTAssertEqual(result.books[0].shelf, .currentlyReading)
        XCTAssertEqual(result.books[0].pageCount, 387)
        XCTAssertEqual(result.books[0].isbn, "9780061054884")
        XCTAssertNil(result.books[1].isbn)
        XCTAssertEqual(result.books[1].shelf, .toRead)
        XCTAssertNil(result.books[1].rating)
        XCTAssertEqual(result.books[2].shelf, .currentlyReading)
        XCTAssertEqual(result.books[2].author, "Someone")
    }

    func testUnmatchedQuoteAndUnknownFormat() {
        XCTAssertThrowsError(try CSVParser.parse("\"hello")) { error in
            XCTAssertEqual(error as? CSVError, .unmatchedQuote)
        }
        XCTAssertThrowsError(try LibraryImporter.detectAndImport("Name,Age\nInky,3\n")) { error in
            XCTAssertEqual(error as? LibraryImportError, .unrecognizedFormat)
        }
        XCTAssertThrowsError(try CSVParser.parse("   \n")) { error in
            XCTAssertEqual(error as? CSVError, .empty)
        }
    }

    func testMissingGoodreadsColumns() throws {
        let csv = "Title,Exclusive Shelf\nHello,to-read\n"
        XCTAssertThrowsError(try LibraryImporter.detectAndImport(csv)) { error in
            guard case LibraryImportError.missingColumns(let format, let columns) = error else {
                return XCTFail("unexpected \(error)")
            }
            XCTAssertEqual(format, .goodreads)
            XCTAssertEqual(columns, ["author"])
        }
    }
}
