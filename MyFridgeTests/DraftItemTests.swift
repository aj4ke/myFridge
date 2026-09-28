import Foundation
import Testing
@testable import MyFridge

struct DraftItemTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    var calculator: ExpiryCalculator {
        ExpiryCalculator(
            shelfLife: ShelfLifeService(daysByCategory: ["dairy_milk": 7, "seafood_raw": 2, "other": 7]),
            foods: FoodShelfLife(groups: [.init(categories: ["other"], foods: ["onion": 60])]),
            memory: ShelfLifeMemory(suiteName: "MyFridgeTests.empty"),
            calendar: calendar
        )
    }

    func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func newDraftExpiresAfterCategoryShelfLife() {
        let draft = DraftItem(name: "Salmon", category: .seafoodRaw, addedDate: date(2026, 9, 20), calculator: calculator)
        #expect(draft.expiryDate == date(2026, 9, 22))
        #expect(draft.isIncluded)
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
}
