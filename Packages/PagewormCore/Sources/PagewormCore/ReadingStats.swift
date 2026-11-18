import Foundation

public struct SpeedSample: Equatable {
    public var pages: Int
    public var minutes: Double

    public init(pages: Int, minutes: Double) {
        self.pages = pages
        self.minutes = minutes
    }
}

public enum ReadingStats {
    /// A gentle default until Pageworm has measured a real session.
    public static let defaultPagesPerHour: Double = 40

    public static func pagesPerHour(pages: Int, minutes: Double) -> Double? {
        guard pages > 0, minutes > 0 else { return nil }
        return Double(pages) / (minutes / 60)
    }

    /// Total pages over total time, which is steadier than an average of rates.
    public static func aggregatePagesPerHour(_ samples: [SpeedSample]) -> Double {
        let useful = samples.filter { $0.pages > 0 && $0.minutes > 0 }
        let pages = useful.reduce(0) { $0 + $1.pages }
        let minutes = useful.reduce(0.0) { $0 + $1.minutes }
        guard pages > 0, minutes > 0 else { return defaultPagesPerHour }
        return Double(pages) / (minutes / 60)
    }
}
