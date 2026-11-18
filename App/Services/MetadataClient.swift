import Foundation
import PagewormCore

struct MetadataClient {
    func lookup(isbn: String?, title: String, author: String) async -> BookMetadata? {
        if let isbn, !isbn.isEmpty,
           let url = OpenLibraryAPI.searchURL(isbn: isbn, title: title, author: author),
           let meta = await fetch(url, parser: OpenLibraryAPI.parseSearch),
           meta.pageCount != nil || meta.coverURL != nil {
            return meta
        }
        if let url = OpenLibraryAPI.searchURL(isbn: nil, title: title, author: author),
           let meta = await fetch(url, parser: OpenLibraryAPI.parseSearch),
           meta.pageCount != nil || meta.coverURL != nil {
            return meta
        }
        if let url = GoogleBooksAPI.searchURL(isbn: isbn, title: title, author: author),
           let meta = await fetch(url, parser: GoogleBooksAPI.parse) {
            return meta
        }
        if isbn != nil,
           let url = GoogleBooksAPI.searchURL(isbn: nil, title: title, author: author),
           let meta = await fetch(url, parser: GoogleBooksAPI.parse) {
            return meta
        }
        return nil
    }

    private func fetch(_ url: URL, parser: (Data) -> BookMetadata?) async -> BookMetadata? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Pageworm/1.0 (iOS; book metadata)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            return nil
        }
        return parser(data)
    }
}
