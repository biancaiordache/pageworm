import Foundation
import PagewormCore

public enum AppGroupStore {
    public static var defaults: UserDefaults? {
        UserDefaults(suiteName: PagewormIDs.appGroup)
    }

    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PagewormIDs.appGroup)
    }

    public static var stateURL: URL? {
        containerURL?.appendingPathComponent(PagewormIDs.stateFileName)
    }

    public static var selectionURL: URL? {
        containerURL?.appendingPathComponent(PagewormIDs.selectionFileName)
    }

    public static func load() -> SharedAppState? {
        guard let url = stateURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? SnapshotCoding.decode(data)
    }

    @discardableResult
    public static func save(_ state: SharedAppState) -> Bool {
        guard let url = stateURL, let data = try? SnapshotCoding.encode(state) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    public static func update(_ mutate: (inout SharedAppState) -> Void) -> SharedAppState {
        var state = load() ?? .initial(now: Date())
        mutate(&state)
        state.updatedAt = Date()
        save(state)
        return state
    }

    public static func setPendingRead(_ pending: Bool) {
        defaults?.set(pending, forKey: PagewormIDs.pendingReadKey)
    }

    public static func consumePendingRead() -> Bool {
        let pending = defaults?.bool(forKey: PagewormIDs.pendingReadKey) ?? false
        if pending {
            defaults?.set(false, forKey: PagewormIDs.pendingReadKey)
        }
        return pending
    }
}
