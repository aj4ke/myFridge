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
    }

    @Test func settersStoreRawValues() {
        item.category = .eggs
        item.source = .receipt
        item.weightUnit = .ounces
        #expect(item.categoryRaw == "eggs")
        #expect(item.sourceRaw == "receipt")
        #expect(item.weightUnitRaw == "oz")
    }

    /** SwiftData saves these strings, so renaming one loses what's already stored. */
    @Test func storedRawValuesDontChange() {
        #expect(ItemSource.allCases.map(\.rawValue) == ["receipt", "screenshot", "manual"])
        #expect(WeightUnit.allCases.map(\.rawValue) == ["lb", "oz"])
    }
}
