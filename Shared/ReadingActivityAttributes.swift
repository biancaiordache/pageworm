import ActivityKit
import Foundation

struct ReadingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var startPage: Int
        var stageRaw: Int
        var moodRaw: String
    }

    var bookTitle: String
    var startedAt: Date
}
