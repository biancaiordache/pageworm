import Foundation

public struct QuizAnswers: Codable, Equatable {
    public var name: String
    public var why: String
    public var dailyPhoneHours: Double
    public var distractingApps: [String]
    public var dailyReadingMinutes: Int
    public var age: Int

    public init(
        name: String,
        why: String,
        dailyPhoneHours: Double,
        distractingApps: [String],
        dailyReadingMinutes: Int,
        age: Int
    ) {
        self.name = name
        self.why = why
        self.dailyPhoneHours = dailyPhoneHours
        self.distractingApps = distractingApps
        self.dailyReadingMinutes = dailyReadingMinutes
        self.age = age
    }
}

public enum OnboardingCopy {
    public static func playback(_ answers: QuizAnswers) -> String {
        let name = answers.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let why = answers.why.trimmingCharacters(in: .whitespacesAndNewlines)
        let apps = join(answers.distractingApps)
        let hours = formatHours(answers.dailyPhoneHours)
        let appClause = apps.isEmpty ? "on my phone" : "on my phone, mostly on \(apps)"
        return "I'm \(name). \(why). I spend \(hours) a day \(appClause). I want to read \(answers.dailyReadingMinutes) minutes a day."
    }

    public static func pledge(name: String) -> String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return "I, \(cleaned), will read before I scroll. When Inky shuts the door, I'll open a book."
    }

    public static func shockYearsLine(years: Double, age: Int) -> String {
        "If you're \(age), at this rate you'll spend \(formatYears(years)) of your life on your phone."
    }

    public static func shockBooksLine(books: Int, apps: [String]) -> String {
        let named = apps.first ?? "that scroll"
        return "That's \(grouped(books)) books you could read instead of \(named)."
    }

    public static func scrollSwapName(apps: [String]) -> String {
        if apps.contains("Instagram") { return "Instagram" }
        if apps.contains("TikTok") { return "TikTok" }
        return apps.first ?? "scroll"
    }

    public static func formatHours(_ hours: Double) -> String {
        if abs(hours - hours.rounded()) < 0.01 {
            let whole = Int(hours.rounded())
            return whole == 1 ? "1 hour" : "\(whole) hours"
        }
        return String(format: "%.1f hours", hours)
    }

    public static func formatYears(_ years: Double) -> String {
        String(format: "%.1f years", years)
    }

    public static func grouped(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    public static func join(_ items: [String]) -> String {
        let cleaned = items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        switch cleaned.count {
        case 0: return ""
        case 1: return cleaned[0]
        case 2: return "\(cleaned[0]) and \(cleaned[1])"
        default:
            let head = cleaned.dropLast().joined(separator: ", ")
            return "\(head), and \(cleaned[cleaned.count - 1])"
        }
    }
}
