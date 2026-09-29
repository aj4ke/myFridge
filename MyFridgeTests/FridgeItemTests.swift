import Foundation
import Testing
@testable import MyFridge

struct FridgeItemTests {
    let item = FridgeItem(name: "Milk", category: .dairyMilk, expiryDate: date(2026, 9, 27))

    @Test func unknownStoredValuesFallBack() {
        item.categoryRaw = "dairy_removed"
        item.sourceRaw = "email"
        item.weightUnitRaw = "kg"
        #expect(item.category == .other)
        #expect(item.source == .manual)
        #expect(item.weightUnit == .pounds)
        item.weightUnitRaw = nil
        #expect(item.weightUnit == .pounds)
        item.locationRaw = "garage"
        #expect(item.location == .fridge)
        item.locationRaw = nil
        #expect(item.location == .fridge)
    }

    @Test func settersStoreRawValues() {
        item.category = .eggs
        item.source = .receipt
        item.weightUnit = .ounces
        item.location = .freezer
        #expect(item.locationRaw == "freezer")
        #expect(item.categoryRaw == "eggs")
        #expect(item.sourceRaw == "receipt")
        #expect(item.weightUnitRaw == "oz")
    }

    /** SwiftData saves these strings, so renaming one loses what's already stored. */
    @Test func storedRawValuesDontChange() {
        #expect(ItemSource.allCases.map(\.rawValue) == ["receipt", "screenshot", "manual"])
        #expect(WeightUnit.allCases.map(\.rawValue) == ["lb", "oz"])
        #expect(StorageLocation.allCases.map(\.rawValue) == ["fridge", "pantry", "freezer"])
    }
}
