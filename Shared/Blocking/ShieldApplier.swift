import FamilyControls
import Foundation
import ManagedSettings
import PagewormCore
import PagewormDesign

/// Applies and clears shields. Compiled into the app and the Device Activity monitor.
enum ShieldApplier {
    private static let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(rawValue: PagewormIDs.managedSettingsStore))

    static func save(_ selection: FamilyActivitySelection) {
        guard let url = AppGroupStore.selectionURL else { return }
        guard let data = try? PropertyListEncoder().encode(selection) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func loadSelection() -> FamilyActivitySelection {
        guard let url = AppGroupStore.selectionURL,
              let data = try? Data(contentsOf: url),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return selection
    }

    static func clear() {
        store.clearAllSettings()
    }

    static func apply(selection: FamilyActivitySelection, isPremium: Bool) {
        var applications = selection.applicationTokens
        if !isPremium {
            if let only = applications.first, applications.count > 1 {
                applications = [only]
            }
            store.shield.applicationCategories = nil
            store.shield.webDomains = nil
        } else {
            store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
            store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        }
        store.shield.applications = applications.isEmpty ? nil : applications
    }

    static func applyIfNeeded(now: Date = Date(), calendar: Calendar = .current) {
        guard let state = AppGroupStore.load() else {
            clear()
            return
        }
        let decision = ShieldPolicy.decision(
            now: now,
            schedule: state.block.schedule,
            unlockEndsAt: state.block.unlockEndsAt,
            calendar: calendar
        )
        switch decision {
        case .shield:
            apply(selection: loadSelection(), isPremium: state.block.isPremium)
        case .clear:
            clear()
        }
    }

    /// Called when an unlock schedule ends. A newer window is left alone.
    static func endUnlockIfExpired(now: Date = Date()) {
        AppGroupStore.update { state in
            if let end = state.block.unlockEndsAt, end <= now.addingTimeInterval(2) {
                state.block.unlockEndsAt = nil
            }
        }
        applyIfNeeded(now: now)
    }
}
