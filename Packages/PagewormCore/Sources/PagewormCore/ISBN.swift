import Foundation

public enum ISBNNormalizer {
    /// Turns Goodreads formula cells (`="978..."`), hyphens, and blanks into a 10- or 13-digit ISBN.
    /// StoryGraph UIDs and empty cells return nil.
    public static func normalize(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if value.hasPrefix("=") {
            value.removeFirst()
        }
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        value = value.replacingOccurrences(of: "-", with: "")
        value = value.replacingOccurrences(of: " ", with: "")
        value = value.uppercased()
        guard value.count == 10 || value.count == 13 else { return nil }
        guard value.allSatisfy({ $0.isNumber || $0 == "X" }) else { return nil }
        if value.count == 10, value.dropLast().contains("X") { return nil }
        if value.count == 13, value.contains("X") { return nil }
        return value
    }
}
