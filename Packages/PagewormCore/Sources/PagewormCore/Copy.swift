import Foundation

public enum InkyCopy {
    public static func playback(name: String, why: String, dailyHours: Double, apps: [String], goalMinutes: Int) -> String {
        let who = cleaned(name).isEmpty ? "Friend" : cleaned(name)
        let reason = cleaned(why).isEmpty ? "to read more" : cleaned(why)
        let (subject, verb) = appSubject(apps)
        let hours = DurationText.hours(max(0, dailyHours))
        let minutes = max(0, goalMinutes)
        return "\(who), you want \(reason), but \(subject) \(verb) about \(hours) a day. You'd like \(minutes) minutes back for books."
    }

    public static func pledge(name: String) -> String {
        let who = cleaned(name).isEmpty ? "I" : cleaned(name)
        return "\(who), I'll read before I scroll."
    }

    public static func shockYears(_ shock: PhoneLifeShock) -> String {
        "At this rate you'll spend \(yearsPhrase(shock.yearsOnPhone)) of your life on your phone."
    }

    public static func shockBooks(_ shock: PhoneLifeShock) -> String {
        let books = shock.booksMissed
        let noun = books == 1 ? "book" : "books"
        return "That's \(grouped(books)) \(noun) you could read."
    }

    public static func shieldTitle(name: String) -> String {
        let who = cleaned(name)
        if who.isEmpty { return "Inky's on this one" }
        return "Inky's on this one, \(who)"
    }

    public static func shieldSubtitle(bookTitle: String, pagesLeft: Int) -> String {
        let title = cleaned(bookTitle)
        if title.isEmpty {
            return "Read a few pages and I'll step aside."
        }
        let pages = max(0, pagesLeft)
        let noun = pages == 1 ? "page" : "pages"
        return "\(pages) \(noun) left in this chapter of \(title)."
    }

    public static func shelfLine(days: Int) -> String {
        if days <= 0 { return "Your shelf is caught up at your pace." }
        if days == 1 { return "Your shelf is 1 day at your pace." }
        return "Your shelf is \(days) days at your pace."
    }

    public static func wrapLine(name: String, pages: Int, streak: Int) -> String {
        let who = cleaned(name).isEmpty ? "You" : cleaned(name)
        let pageWord = pages == 1 ? "page" : "pages"
        let dayWord = streak == 1 ? "day" : "days"
        return "\(who) read \(pages) \(pageWord) this week. Inky is \(streak) \(dayWord) warmer."
    }

    static func appSubject(_ apps: [String]) -> (String, String) {
        let names = apps.map(cleaned).filter { !$0.isEmpty }
        if names.isEmpty { return ("your phone", "takes") }
        if names.count == 1 { return (names[0], "takes") }
        if names.count == 2 { return ("\(names[0]) and \(names[1])", "take") }
        let head = names.dropLast().joined(separator: ", ")
        return ("\(head), and \(names[names.count - 1])", "take")
    }

    static func yearsPhrase(_ years: Double) -> String {
        let rounded = (years * 10).rounded() / 10
        if abs(rounded - rounded.rounded()) < 0.05 {
            let whole = Int(rounded.rounded())
            return whole == 1 ? "1 year" : "\(whole) years"
        }
        return String(format: "%.1f years", rounded)
    }

    static func grouped(_ value: Int) -> String {
        let negative = value < 0
        let digits = Array(String(abs(value)))
        var out = ""
        for (index, character) in digits.enumerated() {
            if index > 0, (digits.count - index) % 3 == 0 {
                out.append(",")
            }
            out.append(character)
        }
        return negative ? "-" + out : out
    }

    static func cleaned(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
