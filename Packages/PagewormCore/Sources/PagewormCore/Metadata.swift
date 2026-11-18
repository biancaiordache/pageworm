import Foundation

public struct BookMetadata: Equatable, Sendable {
    public var title: String?
    public var authors: String?
    public var pageCount: Int?
    public var coverURL: URL?
    public var isbn13: String?

    public init(title: String? = nil, authors: String? = nil, pageCount: Int? = nil, coverURL: URL? = nil, isbn13: String? = nil) {
        self.title = title
        self.authors = authors
        self.pageCount = pageCount
        self.coverURL = coverURL
        self.isbn13 = isbn13
    }

    public var isUseful: Bool {
        pageCount != nil || coverURL != nil || (title?.isEmpty == false)
    }
}

public enum OpenLibraryAPI {
    public static func searchURL(isbn: String?, title: String, author: String) -> URL? {
        var components = URLComponents(string: "https://openlibrary.org/search.json")
        if let isbn = ISBNNormalizer.normalize(isbn) {
            components?.queryItems = [
                URLQueryItem(name: "isbn", value: isbn),
                URLQueryItem(name: "limit", value: "1")
            ]
        } else {
            var query = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let author = author.trimmingCharacters(in: .whitespacesAndNewlines)
            if !author.isEmpty {
                query = query.isEmpty ? author : "\(query) \(author)"
            }
            guard !query.isEmpty else { return nil }
            components?.queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "limit", value: "1")
            ]
        }
        return components?.url
    }

    public static func coverURL(coverID: Int) -> URL? {
        guard coverID > 0 else { return nil }
        return URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-L.jpg")
    }

    public static func parseSearch(_ data: Data) -> BookMetadata? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let docs = json["docs"] as? [[String: Any]],
              let doc = docs.first else {
            return nil
        }
        let title = doc["title"] as? String
        let authors = (doc["author_name"] as? [String])?.joined(separator: ", ")
        let pages = firstInt(doc["number_of_pages_median"]) ?? firstInt(doc["number_of_pages"])
        let cover = firstInt(doc["cover_i"]).flatMap(coverURL(coverID:))
        let isbn = (doc["isbn"] as? [String])?.compactMap(ISBNNormalizer.normalize).first { $0.count == 13 }
            ?? (doc["isbn"] as? [String])?.compactMap(ISBNNormalizer.normalize).first
        let metadata = BookMetadata(title: title, authors: authors, pageCount: pages, coverURL: cover, isbn13: isbn)
        return metadata.isUseful ? metadata : nil
    }

    static func firstInt(_ value: Any?) -> Int? {
        if let value = value as? Int, value > 0 { return value }
        if let value = value as? Double, value > 0 { return Int(value) }
        if let value = value as? NSNumber, value.intValue > 0 { return value.intValue }
        if let values = value as? [Any] {
            return values.compactMap { firstInt($0) }.first
        }
        return nil
    }
}

public enum GoogleBooksAPI {
    public static func searchURL(isbn: String?, title: String, author: String) -> URL? {
        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")
        let query: String
        if let isbn = ISBNNormalizer.normalize(isbn) {
            query = "isbn:\(isbn)"
        } else {
            let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let author = author.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty || !author.isEmpty else { return nil }
            var parts: [String] = []
            if !title.isEmpty { parts.append("intitle:\(title)") }
            if !author.isEmpty { parts.append("inauthor:\(author)") }
            query = parts.joined(separator: "+")
        }
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: "1")
        ]
        return components?.url
    }

    public static func parse(_ data: Data) -> BookMetadata? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]],
              let volume = items.first?["volumeInfo"] as? [String: Any] else {
            return nil
        }
        let title = volume["title"] as? String
        let authors = (volume["authors"] as? [String])?.joined(separator: ", ")
        let pages = OpenLibraryAPI.firstInt(volume["pageCount"])
        let links = volume["imageLinks"] as? [String: Any]
        let rawCover = (links?["thumbnail"] as? String) ?? (links?["smallThumbnail"] as? String)
        let cover = rawCover
            .map { $0.replacingOccurrences(of: "http://", with: "https://") }
            .flatMap(URL.init(string:))
        let identifiers = volume["industryIdentifiers"] as? [[String: Any]]
        let isbn = identifiers?
            .compactMap { $0["identifier"] as? String }
            .compactMap(ISBNNormalizer.normalize)
            .first { $0.count == 13 }
        let metadata = BookMetadata(title: title, authors: authors, pageCount: pages, coverURL: cover, isbn13: isbn)
        return metadata.isUseful ? metadata : nil
    }
}
