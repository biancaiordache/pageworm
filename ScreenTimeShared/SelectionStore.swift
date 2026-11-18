import FamilyControls
import Foundation
import PagewormCore

enum SelectionStore {
    static func load(defaults: UserDefaults = AppGroupDefaults.suite()) -> FamilyActivitySelection {
        guard let data = SharedStore.selectionData(in: defaults) else { return FamilyActivitySelection() }
        return (try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)) ?? FamilyActivitySelection()
    }

    static func save(_ selection: FamilyActivitySelection, defaults: UserDefaults = AppGroupDefaults.suite()) {
        let data = try? PropertyListEncoder().encode(selection)
        SharedStore.setSelectionData(data, in: defaults)
    }
}
