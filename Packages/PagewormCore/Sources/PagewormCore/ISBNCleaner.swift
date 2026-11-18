import Foundation

public enum ISBNCleaner {
    /// Turns Goodreads cells such as `="978..."`, `"=""978..."""`, dashed ISBNs, and blanks into 10- or 13-digit ISBNs.
    public static func clean(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return nil }

        var changed = true
        while changed {
            changed = false
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.hasPrefix("=") {
                value.removeFirst()
                changed = true
                continue
            }
            if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
                changed = true
            }
        }

        value = value
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard value.count == 10 || value.count == 13 else { return nil }
        guard value.allSatisfy({ $0.isNumber || $0 == "X" }) else { return nil }
        if value.count == 10, value.dropLast().contains("X") { return nil }
        if value.count == 13, value.contains("X") { return nil }
        return value
    }
}
