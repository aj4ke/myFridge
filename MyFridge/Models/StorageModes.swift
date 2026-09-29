import Foundation

/** Fridge is always on. Views bind the same keys with @AppStorage. */
nonisolated struct StorageModes: Equatable {
    static let pantryKey = "pantryEnabled"
    static let freezerKey = "freezerEnabled"

    var pantry: Bool
    var freezer: Bool

    init(pantry: Bool = false, freezer: Bool = false) {
        self.pantry = pantry
        self.freezer = freezer
    }

    init(defaults: UserDefaults) {
        self.init(pantry: defaults.bool(forKey: Self.pantryKey), freezer: defaults.bool(forKey: Self.freezerKey))
    }

    static var current: StorageModes {
        StorageModes(defaults: .standard)
    }

    var enabledLocations: [StorageLocation] {
        StorageLocation.allCases.filter(isEnabled)
    }

    func isEnabled(_ location: StorageLocation) -> Bool {
        switch location {
        case .fridge: true
        case .pantry: pantry
        case .freezer: freezer
        }
    }

    /** Items in a turned-off location stay saved but are hidden and get no reminders. */
    @MainActor
    func visible(_ items: [FridgeItem]) -> [FridgeItem] {
        items.filter { isEnabled($0.location) }
    }
}
