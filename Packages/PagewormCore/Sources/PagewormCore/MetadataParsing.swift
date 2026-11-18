import Foundation

public struct ParsedBookMetadata: Equatable {
    public var pageCount: Int?
    public var coverURL: String?
    public var source: String

    public init(pageCount: Int?, coverURL: String?, source: String) {
        self.pageCount = pageCount
        self.coverURL = coverURL
        self.source = source
    }

    public func fillingGaps(from other: ParsedBookMetadata) -> ParsedBookMetadata {
        let sources = [source, other.source].filter { !$0.isEmpty }
        return ParsedBookMetadata(
            pageCount: pageCount ?? other.pageCount,
            coverURL: coverURL ?? other.coverURL,
            source: sources.joined(separator: "+")
        )
    }
}

public enum OpenLibraryParser {
    public static func parseISBNPayload(_ data: Data) -> ParsedBookMetadata? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if json["error"] != nil, json["number_of_pages"] == nil, json["covers"] == nil { return nil }
        let pages = positiveInt(json["number_of_pages"])
        let cover = (json["covers"] as? [Any])?.compactMap(positiveInt).first.map(openLibraryCover(id:))
        if pages == nil, cover == nil { return nil }
        return ParsedBookMetadata(pageCount: pages, coverURL: cover, source: "openlibrary")
    }

    public static func parseSearchPayload(_ data: Data) -> ParsedBookMetadata? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let docs = json["docs"] as? [[String: Any]],
            let first = docs.first
        else { return nil }
        let pages = positiveInt(first["number_of_pages_median"]) ?? positiveInt(first["number_of_pages"])
        let cover = positiveInt(first["cover_i"]).map(openLibraryCover(id:))
        if pages == nil, cover == nil { return nil }
        return ParsedBookMetadata(pageCount: pages, coverURL: cover, source: "openlibrary")
    }

    public static func coverURL(isbn: String) -> String {
        "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg"
    }

    private static func openLibraryCover(id: Int) -> String {
        "https://covers.openlibrary.org/b/id/\(id)-L.jpg"
    }
}

public enum GoogleBooksParser {
    public static func parse(_ data: Data) -> ParsedBookMetadata? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = json["items"] as? [[String: Any]],
            let info = items.first?["volumeInfo"] as? [String: Any]
        else { return nil }
        let pages = positiveInt(info["pageCount"])
        let links = info["imageLinks"] as? [String: Any]
        let rawCover = (links?["thumbnail"] as? String) ?? (links?["smallThumbnail"] as? String)
        let cover = rawCover.map(upgrade)
        if pages == nil, cover == nil { return nil }
        return ParsedBookMetadata(pageCount: pages, coverURL: cover, source: "googlebooks")
    }

    private static func upgrade(_ url: String) -> String {
        var value = url
        if value.hasPrefix("http://") {
            value = "https://" + value.dropFirst("http://".count)
        }
        value = value.replacingOccurrences(of: "zoom=1", with: "zoom=2")
        value = value.replacingOccurrences(of: "&edge=curl", with: "")
        return value
    }
}

private func positiveInt(_ any: Any?) -> Int? {
    let value: Int?
    if let int = any as? Int {
        value = int
    } else if let number = any as? NSNumber {
        value = number.intValue
    } else if let string = any as? String {
        value = Int(string)
    } else {
        value = nil
    }
    guard let value, value > 0 else { return nil }
    return value
}
