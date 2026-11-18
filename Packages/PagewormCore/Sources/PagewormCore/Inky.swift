import Foundation

public enum InkyStage: Int, Codable, CaseIterable, Sendable {
    case sprout = 0
    case bookworm = 1
    case pageEater = 2
    case scholar = 3
    case legend = 4

    public var title: String {
        switch self {
        case .sprout: return "Sprout"
        case .bookworm: return "Bookworm"
        case .pageEater: return "Page-eater"
        case .scholar: return "Scholar"
        case .legend: return "Legend"
        }
    }
}

public enum InkyMood: String, Codable, CaseIterable, Sendable {
    case happy
    case sleepy
    case missingYou

    public var title: String {
        switch self {
        case .happy: return "Happy"
        case .sleepy: return "Sleepy"
        case .missingYou: return "Missing you"
        }
    }
}

public enum InkyEvolution {
    public static func stage(finishedBooks: Int, streak: Int) -> InkyStage {
        let books = max(0, finishedBooks)
        let days = max(0, streak)
        if books >= 25 || days >= 100 { return .legend }
        if books >= 10 || days >= 30 { return .scholar }
        if books >= 3 || days >= 7 { return .pageEater }
        if books >= 1 || days >= 3 { return .bookworm }
        return .sprout
    }

    /// Moods are free. Growing past Sprout is a Plus feature.
    public static func displayedStage(finishedBooks: Int, streak: Int, isPremium: Bool) -> InkyStage {
        let earned = stage(finishedBooks: finishedBooks, streak: streak)
        return isPremium ? earned : .sprout
    }

    public static func mood(lastReadDay: Date?, now: Date, calendar: Calendar) -> InkyMood {
        guard let lastReadDay else { return .sleepy }
        let today = calendar.startOfDay(for: now)
        let last = calendar.startOfDay(for: lastReadDay)
        if last == today { return .happy }
        let hour = calendar.component(.hour, from: now)
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           calendar.startOfDay(for: yesterday) == last {
            return hour >= 20 ? .sleepy : .happy
        }
        return .missingYou
    }
}
