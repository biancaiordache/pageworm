import ActivityKit
import Foundation

public struct ReadingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var startPage: Int
        public var mood: String

        public init(startPage: Int, mood: String) {
            self.startPage = startPage
            self.mood = mood
        }
    }

    public var bookTitle: String
    public var startedAt: Date

    public init(bookTitle: String, startedAt: Date) {
        self.bookTitle = bookTitle
        self.startedAt = startedAt
    }
}
