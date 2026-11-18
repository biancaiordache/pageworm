import ActivityKit
import Foundation
import PagewormActivity

@MainActor
enum LiveActivityController {
    private static let idKey = "pageworm.liveActivityID"

    static func start(title: String, startedAt: Date, startPage: Int, mood: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()
        let attributes = ReadingActivityAttributes(bookTitle: title, startedAt: startedAt)
        let state = ReadingActivityAttributes.ContentState(startPage: startPage, mood: mood)
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            UserDefaults.standard.set(activity.id, forKey: idKey)
        } catch {
            UserDefaults.standard.removeObject(forKey: idKey)
        }
    }

    static func end() {
        let stored = UserDefaults.standard.string(forKey: idKey)
        UserDefaults.standard.removeObject(forKey: idKey)
        Task {
            for activity in Activity<ReadingActivityAttributes>.activities {
                if stored == nil || activity.id == stored {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
    }
}
