import FamilyControls
import Foundation
import ManagedSettings
import PagewormCore

enum ShieldApplier {
    static func apply(decision: ShieldDecision, selection: FamilyActivitySelection) {
        let store = ManagedSettingsStore(named: .init(rawValue: SharedKeys.managedSettingsStoreName))
        guard case .blocked = decision else {
            clear(store)
            return
        }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        if selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = nil
            store.shield.webDomainCategories = nil
        } else {
            store.shield.applicationCategories = .specific(selection.categoryTokens, except: Set<ApplicationToken>())
            store.shield.webDomainCategories = .specific(selection.categoryTokens, except: Set<WebDomainToken>())
        }
    }

    private static func clear(_ store: ManagedSettingsStore) {
        store.shield.applications = nil
        store.shield.webDomains = nil
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
    }
}

enum ShieldRuntime {
    static func reevaluate(now: Date = Date(), defaults: UserDefaults = AppGroupDefaults.suite()) {
        let snapshot = SharedStore.snapshot(in: defaults)
        let decision = ShieldBrain.decide(
            now: now,
            blockingEnabled: snapshot.blockingEnabled,
            schedule: snapshot.schedule,
            unlock: snapshot.unlock,
            calendar: PagewormCalendar.make()
        )
        ShieldApplier.apply(decision: decision, selection: SelectionStore.load(defaults: defaults))
    }
}
