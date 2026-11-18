import Foundation

public enum InkyStage: Int, Codable, CaseIterable, Comparable {
    case bookling = 0
    case pageNibbler
    case chapterChomper
    case novelNommer
    case libraryLegend

    public static func < (lhs: InkyStage, rhs: InkyStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var displayName: String {
        switch self {
        case .bookling: "Bookling"
        case .pageNibbler: "Page Nibbler"
        case .chapterChomper: "Chapter Chomper"
        case .novelNommer: "Novel Nommer"
        case .libraryLegend: "Library Legend"
        }
    }

    public static func stage(streak: Int, finishedBooks: Int) -> InkyStage {
        if streak >= 60 || finishedBooks >= 20 { return .libraryLegend }
        if streak >= 21 || finishedBooks >= 8 { return .novelNommer }
        if streak >= 7 || finishedBooks >= 3 { return .chapterChomper }
        if streak >= 3 || finishedBooks >= 1 { return .pageNibbler }
        return .bookling
    }

    public static func visibleStage(streak: Int, finishedBooks: Int, isPremium: Bool) -> InkyStage {
        let real = stage(streak: streak, finishedBooks: finishedBooks)
        return isPremium ? real : .bookling
    }

    public var next: InkyStage? {
        InkyStage(rawValue: rawValue + 1)
    }
}

public enum InkyMood: String, Codable, CaseIterable {
    case happy
    case sleepy
    case missingYou
    case cheering

    public var label: String {
        switch self {
        case .happy: "happy"
        case .sleepy: "sleepy"
        case .missingYou: "missing you"
        case .cheering: "cheering"
        }
    }
}

public enum InkyMoodDecider {
    public static func mood(
        now: Date,
        lastSessionEndedAt: Date?,
        readToday: Bool,
        justFinishedBook: Bool,
        calendar: Calendar
    ) -> InkyMood {
        if justFinishedBook { return .cheering }
        if let lastSessionEndedAt, now.timeIntervalSince(lastSessionEndedAt) > 36 * 60 * 60 {
            return .missingYou
        }
        if let lastSessionEndedAt, now.timeIntervalSince(lastSessionEndedAt) < 20 * 60 {
            return .sleepy
        }
        let hour = calendar.component(.hour, from: now)
        if (hour >= 23 || hour < 6) && !readToday {
            return .sleepy
        }
        return .happy
    }
}
