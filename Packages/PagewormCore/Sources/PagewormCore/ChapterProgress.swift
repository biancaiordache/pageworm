import Foundation

public enum ChapterProgress {
    /// Estimates the next chapter break. Real chapter maps are not in the book APIs we use, so a chapter is `pagesPerChapter` pages (15 by default). The result is capped by the pages left in the book.
    public static func pagesUntilNextChapter(currentPage: Int, pageCount: Int?, pagesPerChapter: Int) -> Int {
        let size = max(pagesPerChapter, 1)
        let page = max(currentPage, 0)
        if let pageCount, page >= pageCount { return 0 }
        let remainder = page % size
        var left = remainder == 0 ? size : size - remainder
        if let pageCount, pageCount > page {
            left = min(left, pageCount - page)
        }
        return left
    }
}
