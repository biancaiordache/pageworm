import Foundation

public enum ScrollConversion {
    public static func pages(from duration: TimeInterval, pagesPerHour: Double) -> Int {
        guard duration > 0, pagesPerHour > 0 else { return 0 }
        return Int(((duration / 3600) * pagesPerHour).rounded())
    }

    public static func summary(duration: TimeInterval, pagesPerHour: Double, sourceName: String?) -> String {
        let pages = pages(from: duration, pagesPerHour: pagesPerHour)
        let time = format(hours: duration / 3600)
        if let sourceName, !sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(time) back from \(sourceName) is \(pages) pages"
        }
        return "\(time) back is \(pages) pages"
    }

    public static func format(hours: Double) -> String {
        guard hours > 0 else { return "0m" }
        if hours >= 1 {
            let rounded = (hours * 10).rounded() / 10
            if abs(rounded - rounded.rounded()) < 0.001 {
                return "\(Int(rounded))h"
            }
            return String(format: "%.1fh", rounded)
        }
        return "\(max(1, Int((hours * 60).rounded())))m"
    }
}
