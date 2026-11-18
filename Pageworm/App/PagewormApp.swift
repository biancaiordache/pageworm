import SwiftData
import SwiftUI

@main
struct PagewormApp: App {
    private let container: ModelContainer

    init() {
        let schema = Schema([UserProfile.self, Book.self, ReadingSessionRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Pageworm couldn't open its library: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
