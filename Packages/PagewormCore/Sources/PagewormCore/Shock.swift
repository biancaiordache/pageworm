import Foundation

public struct PhoneLifeShock: Equatable, Sendable {
    public var yearsOnPhone: Double
    public var booksMissed: Int
    public var lifetimePhoneHours: Double

    public init(yearsOnPhone: Double, booksMissed: Int, lifetimePhoneHours: Double) {
        self.yearsOnPhone = yearsOnPhone
        self.booksMissed = booksMissed
        self.lifetimePhoneHours = lifetimePhoneHours
    }
}

public enum ShockMath {
    /// Years of phone use still ahead, used when onboarding doesn't ask for age.
    public static let assumedYearsRemaining: Double = 50
    public static let assumedPagesPerBook: Int = 320
    public static let assumedPagesPerHour: Double = 30

    public static func calculate(
        dailyPhoneHours: Double,
        yearsRemaining: Double = assumedYearsRemaining,
        pagesPerBook: Int = assumedPagesPerBook,
        pagesPerHour: Double = assumedPagesPerHour
    ) -> PhoneLifeShock {
        let hoursPerDay = max(0, dailyPhoneHours)
        let years = max(0, yearsRemaining)
        let yearsOnPhone = hoursPerDay * years / 24
        let lifetimeHours = hoursPerDay * 365.25 * years
        let safePagesPerHour = max(pagesPerHour, 1)
        let bookHours = Double(max(pagesPerBook, 1)) / safePagesPerHour
        let books = Int((lifetimeHours / bookHours).rounded(.down))
        return PhoneLifeShock(
            yearsOnPhone: yearsOnPhone,
            booksMissed: books,
            lifetimePhoneHours: lifetimeHours
        )
    }
}
