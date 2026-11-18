import Foundation

public enum ReadingShelf: String, Codable, CaseIterable, Sendable {
    case toRead
    case currentlyReading
    case read
    case didNotFinish
    case other

    public var title: String {
        switch self {
        case .toRead: return "To read"
        case .currentlyReading: return "Reading"
        case .read: return "Finished"
        case .didNotFinish: return "Set aside"
        case .other: return "Other"
        }
    }
}

public enum LibrarySource: String, Codable, Sendable {
    case goodreads
    case storyGraph
    case manual
    case unknown
}

public struct ImportedBook: Equatable, Sendable, Codable {
    public var title: String
    public var authors: String
    public var isbn: String?
    public var pageCount: Int?
    public var shelf: ReadingShelf
    public var dateAdded: Date?
    public var rating: Double?
    public var source: LibrarySource

    public init(
        title: String,
        authors: String,
        isbn: String?,
        pageCount: Int?,
        shelf: ReadingShelf,
        dateAdded: Date?,
        rating: Double?,
        source: LibrarySource
    ) {
        self.title = title
        self.authors = authors
        self.isbn = isbn
        self.pageCount = pageCount
        self.shelf = shelf
        self.dateAdded = dateAdded
        self.rating = rating
        self.source = source
    }
}

public struct LibraryImport: Equatable, Sendable {
    public var source: LibrarySource
    public var books: [ImportedBook]
    public var skipped: Int

    public init(source: LibrarySource, books: [ImportedBook], skipped: Int) {
        self.source = source
        self.books = books
        self.skipped = skipped
    }

    public func count(on shelf: ReadingShelf) -> Int {
        books.filter { $0.shelf == shelf }.count
    }
}

public enum LibraryCSVParser {
    public static func parse(_ csv: String, calendar: Calendar = .current) -> LibraryImport {
        let table = CSVDecoder.parse(csv)
        let source = detectSource(headers: table.headers)
        let preferDayFirst = source == .storyGraph
        var books: [ImportedBook] = []
        var skipped = 0

        for row in table.rows {
            guard let book = parseRow(row, source: source, preferDayFirst: preferDayFirst, calendar: calendar) else {
                skipped += 1
                continue
            }
            books.append(book)
        }
        return LibraryImport(source: source, books: books, skipped: skipped)
    }

    public static func detectSource(headers: [String]) -> LibrarySource {
        let set = Set(headers.map(CSVDecoder.normalizeHeader))
        if set.contains("exclusive shelf") || set.contains("isbn13") || set.contains("book id") {
            return .goodreads
        }
        if set.contains("read status") || set.contains("isbn/uid") {
            return .storyGraph
        }
        return .unknown
    }

    static func parseRow(
        _ row: [String: String],
        source: LibrarySource,
        preferDayFirst: Bool,
        calendar: Calendar
    ) -> ImportedBook? {
        let title = field(row, ["title"])
        guard !title.isEmpty else { return nil }

        let primaryAuthor = field(row, ["author", "authors"])
        let extra = field(row, ["additional authors", "contributors"])
        let authors = joinAuthors(primaryAuthor, extra)

        let isbn = ISBNNormalizer.normalize(field(row, ["isbn13", "isbn/uid", "isbn"]))
            ?? ISBNNormalizer.normalize(field(row, ["isbn"]))
        let pages = intField(row, ["number of pages", "pages", "page count", "number of pages median"])
        let shelf = mapShelf(field(row, ["exclusive shelf", "read status", "bookshelves", "shelf"]))
        let added = DateParsing.parse(field(row, ["date added"]), preferDayFirst: preferDayFirst, calendar: calendar)
        let rating = ratingField(row, ["my rating", "star rating", "rating"])

        return ImportedBook(
            title: title,
            authors: authors,
            isbn: isbn,
            pageCount: pages,
            shelf: shelf,
            dateAdded: added,
            rating: rating,
            source: source
        )
    }

    static func field(_ row: [String: String], _ keys: [String]) -> String {
        for key in keys {
            if let value = row[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }
        return ""
    }

    static func joinAuthors(_ primary: String, _ extra: String) -> String {
        let extras = extra
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.caseInsensitiveCompare(primary) != .orderedSame }
        if primary.isEmpty { return extras.joined(separator: ", ") }
        if extras.isEmpty { return primary }
        return ([primary] + extras).joined(separator: ", ")
    }

    static func intField(_ row: [String: String], _ keys: [String]) -> Int? {
        let raw = field(row, keys)
        guard !raw.isEmpty else { return nil }
        let cleaned = raw.replacingOccurrences(of: ",", with: "")
        if let value = Int(cleaned), value > 0 { return value }
        if let value = Double(cleaned), value > 0 { return Int(value) }
        return nil
    }

    static func ratingField(_ row: [String: String], _ keys: [String]) -> Double? {
        let raw = field(row, keys)
        guard let value = Double(raw), value > 0 else { return nil }
        return value
    }

    public static func mapShelf(_ raw: String) -> ReadingShelf {
        let folded = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let compact = folded.replacingOccurrences(of: " ", with: "")
        switch compact {
        case "toread", "wanttoread", "tbr":
            return .toRead
        case "currentlyreading", "reading", "currentlyread":
            return .currentlyReading
        case "read", "finished":
            return .read
        case "didnotfinish", "dnf", "paused":
            return .didNotFinish
        default:
            if folded.contains("currently") { return .currentlyReading }
            if folded.contains("to read") || folded.contains("want to read") { return .toRead }
            if folded.contains("did not finish") { return .didNotFinish }
            return .other
        }
    }
}
