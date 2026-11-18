import Foundation

public enum AttentionMath {
    public static let defaultAge = 25
    public static let defaultLifeExpectancy = 80
    public static let defaultPagesPerBook = 320

    public static func yearsOnPhone(dailyHours: Double, age: Int, lifeExpectancy: Int = defaultLifeExpectancy) -> Double {
        let yearsLeft = max(0, lifeExpectancy - max(age, 0))
        return max(0, dailyHours) * Double(yearsLeft) / 24
    }

    public static func booksYouCouldRead(
        dailyHours: Double,
        age: Int,
        lifeExpectancy: Int = defaultLifeExpectancy,
        pagesPerBook: Int = defaultPagesPerBook,
        pagesPerHour: Double = ReadingStats.defaultPagesPerHour
    ) -> Int {
        let years = yearsOnPhone(dailyHours: dailyHours, age: age, lifeExpectancy: lifeExpectancy)
        let hours = years * 365.25 * 24
        let hoursPerBook = Double(max(pagesPerBook, 1)) / max(pagesPerHour, 1)
        return Int((hours / hoursPerBook).rounded())
    }
}
