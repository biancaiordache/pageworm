import Foundation

public enum ImportFormat: String, Codable, Equatable {
    case goodreads
    case storyGraph
}

public enum ReadingShelf: String, Codable, CaseIterable, Equatable {
    case toRead = "to-read"
    case currentlyReading = "currently-reading"
    case read = "read"
    case other = "other"

    public var title: String {
        switch self {
        case .toRead: "To read"
        case .currentlyReading: "Currently reading"
        case .read: "Read"
        case .other: "Other"
        }
    }
}

public struct ImportedBook: Equatable, Codable {
    public var title: String
    public var author: String
    public var isbn: String?
    public var pageCount: Int?
    public var shelf: ReadingShelf
    public var dateAdded: Date?
    public var rating: Double?
    public var source: ImportFormat

    public init(
        title: String,
        author: String,
        isbn: String?,
        pageCount: Int?,
        shelf: ReadingShelf,
        dateAdded: Date?,
        rating: Double?,
        source: ImportFormat
    ) {
        self.title = title
        self.author = author
        self.isbn = isbn
        self.pageCount = pageCount
        self.shelf = shelf
        self.dateAdded = dateAdded
        self.rating = rating
        self.source = source
    }
}

public enum LibraryImportError: Error, Equatable {
    case empty
    case unrecognizedFormat
    case missingColumns(format: ImportFormat, columns: [String])
}

public enum LibraryImporter {
    public static func detectAndImport(_ text: String) throws -> (format: ImportFormat, books: [ImportedBook]) {
        let document: CSVDocument
        do {
            document = try CSVParser.parse(text)
        } catch CSVError.empty {
            throw LibraryImportError.empty
        }
        let headers = Set(document.headers.map { normalized($0) })
        if headers.contains("exclusive shelf") {
            return (.goodreads, try importGoodreads(document))
        }
        if headers.contains("read status") {
            return (.storyGraph, try importStoryGraph(document))
        }
        throw LibraryImportError.unrecognizedFormat
    }

    public static func importGoodreads(_ document: CSVDocument) throws -> [ImportedBook] {
        try require(document, format: .goodreads, columns: ["title", "author", "exclusive shelf"])
        return document.rows.compactMap { row in
            let fields = lowered(row)
            let title = fields["title", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            let author = firstNonEmpty(fields["author"], fields["author l-f"]) ?? "Unknown"
            let isbn = ISBNCleaner.clean(fields["isbn13", default: ""])
                ?? ISBNCleaner.clean(fields["isbn", default: ""])
            return ImportedBook(
                title: title,
                author: author,
                isbn: isbn,
                pageCount: intField(fields["number of pages"]),
                shelf: mapShelf(fields["exclusive shelf"] ?? fields["bookshelves"] ?? ""),
                dateAdded: dateField(fields["date added"]),
                rating: ratingField(fields["my rating"]),
                source: .goodreads
            )
        }
    }

    public static func importStoryGraph(_ document: CSVDocument) throws -> [ImportedBook] {
        try require(document, format: .storyGraph, columns: ["title", "read status"])
        return document.rows.compactMap { row in
            let fields = lowered(row)
            let title = fields["title", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            let isbnRaw = fields["isbn/uid"] ?? fields["isbn"] ?? fields["isbn13"] ?? ""
            return ImportedBook(
                title: title,
                author: firstNonEmpty(fields["authors"], fields["author"]) ?? "Unknown",
                isbn: ISBNCleaner.clean(isbnRaw),
                pageCount: intField(fields["pages"] ?? fields["number of pages"]),
                shelf: mapShelf(fields["read status"] ?? ""),
                dateAdded: dateField(fields["date added"]),
                rating: ratingField(fields["star rating"] ?? fields["rating"]),
                source: .storyGraph
            )
        }
    }

    private static func require(_ document: CSVDocument, format: ImportFormat, columns: [String]) throws {
        let headers = Set(document.headers.map { normalized($0) })
        let missing = columns.filter { !headers.contains($0) }
        if !missing.isEmpty {
            throw LibraryImportError.missingColumns(format: format, columns: missing)
        }
    }

    private static func lowered(_ row: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in row {
            let name = normalized(key)
            if result[name] == nil {
                result[name] = value
            }
        }
        return result
    }

    private static func normalized(_ header: String) -> String {
        header.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func mapShelf(_ raw: String) -> ReadingShelf {
        let value = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
        let flattened = value.replacingOccurrences(of: " ", with: "-")
        switch flattened {
        case "to-read", "want-to-read", "tbr":
            return .toRead
        case "currently-reading", "currently", "reading", "paused":
            return .currentlyReading
        case "read", "finished", "complete", "completed":
            return .read
        default:
            if flattened.contains("currently-reading") { return .currentlyReading }
            if flattened.contains("to-read") { return .toRead }
            if flattened == "did-not-finish" || flattened == "dnf" { return .other }
            return .other
        }
    }

    private static func intField(_ raw: String?) -> Int? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if let value = Int(trimmed) { return value > 0 ? value : nil }
        if let value = Double(trimmed) {
            let pages = Int(value.rounded())
            return pages > 0 ? pages : nil
        }
        return nil
    }

    private static func ratingField(_ raw: String?) -> Double? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0, value <= 5 else { return nil }
        return value
    }

    private static func dateField(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let formats = ["yyyy/MM/dd", "yyyy-MM-dd", "yyyy-MM-dd'T'HH:mm:ssXXXXX", "yyyy-MM-dd HH:mm:ss"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return ISO8601DateFormatter().date(from: trimmed)
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }
}
