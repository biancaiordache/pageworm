import Foundation

public struct ShelfBook: Equatable {
    public var pageCount: Int?
    public var currentPage: Int
    public var shelf: ReadingShelf

    public init(pageCount: Int?, currentPage: Int, shelf: ReadingShelf) {
        self.pageCount = pageCount
        self.currentPage = currentPage
        self.shelf = shelf
    }
}

public struct TBRCountdown: Equatable {
    public var days: Int
    public var knownBooks: Int
    public var unknownPageBooks: Int
    public var totalPages: Int

    public init(days: Int, knownBooks: Int, unknownPageBooks: Int, totalPages: Int) {
        self.days = days
        self.knownBooks = knownBooks
        self.unknownPageBooks = unknownPageBooks
        self.totalPages = totalPages
    }
}

public enum TBRMath {
    /// To-read books count in full. The current book counts only the pages still ahead. Read books stay off the shelf clock.
    public static func countdown(
        books: [ShelfBook],
        pagesPerHour: Double,
        minutesPerDay: Int
    ) -> TBRCountdown {
        let speed = pagesPerHour > 0 ? pagesPerHour : ReadingStats.defaultPagesPerHour
        let dailyMinutes = max(minutesPerDay, 1)
        var pages = 0
        var known = 0
        var unknown = 0
        for book in books {
            switch book.shelf {
            case .read, .other:
                continue
            case .toRead:
                if let count = book.pageCount, count > 0 {
                    pages += count
                    known += 1
                } else {
                    unknown += 1
                }
            case .currentlyReading:
                if let count = book.pageCount, count > 0 {
                    pages += max(0, count - max(book.currentPage, 0))
                    known += 1
                } else {
                    unknown += 1
                }
            }
        }
        let pagesPerDay = speed * (Double(dailyMinutes) / 60)
        let days = pages == 0 ? 0 : Int((Double(pages) / pagesPerDay).rounded(.up))
        return TBRCountdown(days: days, knownBooks: known, unknownPageBooks: unknown, totalPages: pages)
    }
}
