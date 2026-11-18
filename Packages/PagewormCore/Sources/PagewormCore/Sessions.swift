import Foundation

public enum SessionRules {
    public static let minimumMinutes = 5

    public static func pagesRead(start: Int, end: Int) -> Int {
        max(0, end - start)
    }

    public static func qualifies(durationSeconds: Int, pagesRead: Int, minimumMinutes: Int = minimumMinutes) -> Bool {
        durationSeconds >= minimumMinutes * 60 && pagesRead >= 1
    }
}

public enum ScrollToBooks {
    public static func pages(hours: Double, pagesPerHour: Double) -> Int {
        Int((max(0, hours) * max(0, pagesPerHour)).rounded())
    }

    public static func summary(appName: String, hours: Double, pagesPerHour: Double) -> String {
        let name = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = name.isEmpty ? "scrolling" : name
        let count = pages(hours: hours, pagesPerHour: pagesPerHour)
        let pageWord = count == 1 ? "page" : "pages"
        return "\(DurationText.compactHours(hours)) back from \(label) is \(count) \(pageWord)"
    }
}

public enum DurationText {
    public static func hours(_ hours: Double) -> String {
        let rounded = (hours * 10).rounded() / 10
        if abs(rounded - rounded.rounded()) < 0.001 {
            let whole = Int(rounded.rounded())
            return whole == 1 ? "1 hour" : "\(whole) hours"
        }
        return String(format: "%.1f hours", rounded)
    }

    public static func compactHours(_ hours: Double) -> String {
        let rounded = (hours * 10).rounded() / 10
        if abs(rounded - rounded.rounded()) < 0.001 {
            return "\(Int(rounded.rounded()))h"
        }
        return String(format: "%.1fh", rounded)
    }
}
