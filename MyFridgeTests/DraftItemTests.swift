import Foundation
import Testing
@testable import MyFridge

struct DraftItemTests {
    let calculator = ExpiryCalculator.testing(
        shelfLife: ShelfLifeService(daysByCategory: ["dairy_milk": 7, "seafood_raw": 2, "other": 7]),
        foods: FoodShelfLife(groups: [.init(categories: ["other"], foods: ["onion": 60])])
    )

    @Test func newDraftExpiresAfterCategoryShelfLife() {
        let draft = DraftItem(name: "Salmon", category: .seafoodRaw, addedDate: date(2026, 9, 20), calculator: calculator)
        #expect(draft.expiryDate == date(2026, 9, 22))
        #expect(draft.isIncluded)
    }

    @Test func manualDraftDefaults() {
        let draft = DraftItem(addedDate: date(2026, 9, 20), calculator: calculator)
        #expect(draft.category == .other)
        #expect(draft.quantity == 1)
        #expect(draft.weightPounds == nil)
        #expect(draft.weightUnit == .pounds)
        #expect(draft.source == .manual)
        #expect(draft.isIncluded)
        #expect(!draft.expiryEdited)
        #expect(draft.expiryDate == date(2026, 9, 27))
    }

    @Test func nonFridgeImportsStartUnchecked() {
        let draft = DraftItem(name: "Soup", addedDate: date(2026, 9, 20), source: .screenshot, needsRefrigeration: false, calculator: calculator)
        #expect(!draft.isIncluded)
    }

    @Test func purchaseDateRecalculatesUneditedExpiry() {
        var draft = DraftItem(name: "Milk", category: .dairyMilk, addedDate: date(2026, 9, 25), calculator: calculator)
        draft.setAddedDate(date(2026, 9, 20), calculator: calculator)
        #expect(draft.addedDate == date(2026, 9, 20))
        #expect(draft.expiryDate == date(2026, 9, 27))
    }

    @Test func purchaseDateKeepsHandPickedExpiry() {
        var draft = DraftItem(name: "Milk", category: .dairyMilk, addedDate: date(2026, 9, 25), calculator: calculator)
        draft.expiryDate = date(2026, 10, 15)
        draft.expiryEdited = true
        draft.setAddedDate(date(2026, 9, 20), calculator: calculator)
        #expect(draft.expiryDate == date(2026, 10, 15))
    }

    @Test func editingSavedItemDetectsHandPickedExpiry() {
        let calculated = FridgeItem(name: "Milk", category: .dairyMilk, addedDate: date(2026, 9, 20), expiryDate: date(2026, 9, 27))
        let handPicked = FridgeItem(name: "Milk", category: .dairyMilk, addedDate: date(2026, 9, 20), expiryDate: date(2026, 10, 15))
        #expect(!DraftItem(calculated, calculator: calculator).expiryEdited)
        #expect(DraftItem(handPicked, calculator: calculator).expiryEdited)
    }

    @Test func editingSavedItemCopiesEveryField() {
        let item = FridgeItem(
            name: "Atlantic Salmon",
            category: .seafoodRaw,
            subcategory: "Salmon",
            quantity: 2,
            weightPounds: 1.5,
            weightUnit: .ounces,
            addedDate: date(2026, 9, 20),
            expiryDate: date(2026, 9, 22),
            source: .receipt
        )
        let draft = DraftItem(item, calculator: calculator)
        #expect(draft.name == "Atlantic Salmon")
        #expect(draft.category == .seafoodRaw)
        #expect(draft.subcategory == "Salmon")
        #expect(draft.quantity == 2)
        #expect(draft.weightPounds == 1.5)
        #expect(draft.weightUnit == .ounces)
        #expect(draft.addedDate == date(2026, 9, 20))
        #expect(draft.expiryDate == date(2026, 9, 22))
        #expect(draft.source == .receipt)
        #expect(draft.isIncluded)
        #expect(draft.needsRefrigeration)
    }

    @Test func nameSetsExpiry() {
        var draft = DraftItem(name: "Red Onion", category: .other, addedDate: date(2026, 9, 20), calculator: calculator)
        #expect(draft.expiryDate == date(2026, 11, 19))
        draft.name = "Garlic"
        draft.recalculateExpiry(calculator: calculator)
        #expect(draft.expiryDate == date(2026, 9, 27))
    }

    @Test func editingSavedItemUsesFoodTable() {
        let onion = FridgeItem(name: "Red Onion", category: .other, addedDate: date(2026, 9, 20), expiryDate: date(2026, 11, 19))
        #expect(!DraftItem(onion, calculator: calculator).expiryEdited)
    }

    @Test func savesEveryFieldToFridgeItem() {
        var draft = DraftItem(
            name: "Center Cut Atlantic Salmon",
            category: .seafoodRaw,
            quantity: 2,
            weight: (pounds: 1.11, unit: .pounds),
            addedDate: date(2026, 9, 20),
            source: .screenshot,
            calculator: calculator
        )
        draft.subcategory = "Salmon"

        let item = FridgeItem(draft)
        #expect(item.name == "Center Cut Atlantic Salmon")
        #expect(item.category == .seafoodRaw)
        #expect(item.subcategory == "Salmon")
        #expect(item.quantity == 2)
        #expect(item.weightPounds == 1.11)
        #expect(item.weightUnit == .pounds)
        #expect(item.addedDate == date(2026, 9, 20))
        #expect(item.expiryDate == date(2026, 9, 22))
        #expect(item.source == .screenshot)
    }

    /** Imports keep a weight for any category, even ones that hide the weight row when adding by hand. */
    @Test func importedWeightIsSavedForAnyCategory() {
        let onion = DraftItem(
            name: "Organic Red Onion",
            category: .produceOther,
            weight: (pounds: 0.88, unit: .pounds),
            addedDate: date(2026, 9, 20),
            source: .screenshot,
            calculator: calculator
        )
        let cheese = DraftItem(
            name: "Cheddar",
            category: .cheeseHard,
            weight: (pounds: 0.75, unit: .ounces),
            addedDate: date(2026, 9, 20),
            source: .receipt,
            calculator: calculator
        )
        #expect(!FoodCategory.produceOther.tracksWeight)
        #expect(FridgeItem(onion).weightPounds == 0.88)
        #expect(FridgeItem(cheese).weightPounds == 0.75)
        #expect(FridgeItem(cheese).weightUnit == .ounces)
    }

    @Test func applyUpdatesEditsButKeepsSourceAndID() {
        let item = FridgeItem(name: "Milk", category: .dairyMilk, addedDate: date(2026, 9, 20), expiryDate: date(2026, 9, 27), source: .receipt)
        let id = item.id
        var draft = DraftItem(item, calculator: calculator)
        draft.name = "Oat Milk"
        draft.subcategory = "Oat"
        draft.quantity = 3
        draft.weightPounds = 0.5
        draft.weightUnit = .ounces
        draft.source = .manual
        draft.setAddedDate(date(2026, 9, 21), calculator: calculator)

        item.apply(draft)
        #expect(item.name == "Oat Milk")
        #expect(item.subcategory == "Oat")
        #expect(item.quantity == 3)
        #expect(item.weightPounds == 0.5)
        #expect(item.weightUnit == .ounces)
        #expect(item.addedDate == date(2026, 9, 21))
        #expect(item.expiryDate == date(2026, 9, 28))
        #expect(item.source == .receipt)
        #expect(item.id == id)
    }
}
