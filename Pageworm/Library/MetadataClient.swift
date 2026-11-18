import Foundation
import PagewormCore

actor MetadataClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func enrich(isbn: String?, title: String, author: String) async -> ParsedBookMetadata? {
        var merged: ParsedBookMetadata?
        if let isbn, let url = URL(string: "https://openlibrary.org/isbn/\(isbn).json"),
           let parsed = await fetch(url, parse: OpenLibraryParser.parseISBNPayload) {
            merged = parsed
        }
        if merged?.pageCount == nil || merged?.coverURL == nil {
            if let url = searchURL(title: title, author: author),
               let parsed = await fetch(url, parse: OpenLibraryParser.parseSearchPayload) {
                merged = merged?.fillingGaps(from: parsed) ?? parsed
            }
        }
        if merged?.pageCount == nil || merged?.coverURL == nil {
            if let url = googleURL(isbn: isbn, title: title, author: author),
               let parsed = await fetch(url, parse: GoogleBooksParser.parse) {
                merged = merged?.fillingGaps(from: parsed) ?? parsed
            }
        }
        if merged?.coverURL == nil, let isbn {
            let cover = ParsedBookMetadata(pageCount: nil, coverURL: OpenLibraryParser.coverURL(isbn: isbn), source: "openlibrary")
            merged = merged?.fillingGaps(from: cover) ?? cover
        }
        return merged
    }

    private func fetch(_ url: URL, parse: (Data) -> ParsedBookMetadata?) async -> ParsedBookMetadata? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Pageworm/1.0 (reading app; metadata lookup)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else { return nil }
        return parse(data)
    }

    private func searchURL(title: String, author: String) -> URL? {
        var components = URLComponents(string: "https://openlibrary.org/search.json")
        components?.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "author", value: author),
            URLQueryItem(name: "limit", value: "1")
        ]
        return components?.url
    }

    private func googleURL(isbn: String?, title: String, author: String) -> URL? {
        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")
        let query: String
        if let isbn, !isbn.isEmpty {
            query = "isbn:\(isbn)"
        } else {
            query = "intitle:\(title) inauthor:\(author)"
        }
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }
}
