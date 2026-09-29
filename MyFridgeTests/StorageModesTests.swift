import Foundation
import Testing
@testable import MyFridge

struct StorageModesTests {
    @Test(arguments: [
        (false, false, [StorageLocation.fridge]),
        (true, false, [.fridge, .pantry]),
        (false, true, [.fridge, .freezer]),
        (true, true, [.fridge, .pantry, .freezer]),
    ])
    func fridgeIsAlwaysOn(pantry: Bool, freezer: Bool, expected: [StorageLocation]) {
        let modes = StorageModes(pantry: pantry, freezer: freezer)
        #expect(modes.enabledLocations == expected)
        #expect(modes.isEnabled(.fridge))
    }

    /** The list and notification rescheduling both go through this. */
    @Test func hidesItemsInTurnedOffLocations() {
        let items = StorageLocation.allCases.map {
            FridgeItem(name: $0.displayName, category: .other, expiryDate: date(2026, 9, 27), location: $0)
        }
        #expect(StorageModes().visible(items).map(\.location) == [.fridge])
        #expect(StorageModes(freezer: true).visible(items).map(\.location) == [.fridge, .freezer])
        #expect(StorageModes(pantry: true, freezer: true).visible(items).count == 3)
    }

    @Test func readsTogglesFromDefaults() {
        let suiteName = "MyFridgeTests.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let defaults = UserDefaults(suiteName: suiteName)!
        #expect(StorageModes(defaults: defaults) == StorageModes())

        defaults.set(true, forKey: StorageModes.freezerKey)
        #expect(StorageModes(defaults: defaults) == StorageModes(pantry: false, freezer: true))
    }
}
