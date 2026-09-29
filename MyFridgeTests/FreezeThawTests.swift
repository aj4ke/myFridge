import Foundation
import Testing
@testable import MyFridge

struct FreezeThawTests {
    let calculator = ExpiryCalculator.testing(
        shelfLife: ShelfLifeService(
            daysByLocation: [
                .fridge: ["meat_raw": 3, "bread_bakery": 14, "frozen_meals": 3, "other": 7],
                .pantry: ["bread_bakery": 5, "other": 30],
                .freezer: ["meat_raw": 120, "bread_bakery": 90, "frozen_meals": 360, "other": 60],
            ],
            thawedDaysByCategory: ["meat_raw": 3]
        ),
        foods: FoodShelfLife(
            groupsByLocation: [.freezer: [.init(categories: ["meat_raw"], foods: ["ground": 90])]],
            thawedGroups: [.init(categories: ["meat_raw"], foods: ["ground": 1])]
        )
    )

    @Test func boughtFrozenCountsFromPurchase() {
        let pizza = DraftItem(name: "Pizza", category: .frozenMeals, addedDate: date(2026, 9, 20), location: .freezer, calculator: calculator)
        #expect(pizza.frozenDate == date(2026, 9, 20))
        #expect(pizza.expiryDate == date(2027, 9, 15))
    }

    @Test func purchaseDateMovesBoughtFrozenDate() {
        var pizza = DraftItem(name: "Pizza", category: .frozenMeals, addedDate: date(2026, 9, 20), location: .freezer, calculator: calculator)
        pizza.setAddedDate(date(2026, 9, 10), calculator: calculator)
        #expect(pizza.frozenDate == date(2026, 9, 10))
        #expect(pizza.expiryDate == date(2027, 9, 5))
    }

    @Test func freezingCountsFromTheFreezeDay() {
        var steak = DraftItem(name: "Steak", category: .meatRaw, addedDate: date(2026, 9, 20), calculator: calculator)
        steak.freeze(on: date(2026, 9, 22, hour: 18), calculator: calculator)
        #expect(steak.location == .freezer)
        #expect(steak.frozenDate == date(2026, 9, 22))
        #expect(steak.expiryDate == date(2027, 1, 20))
    }

    @Test func freezingDropsHandPickedExpiry() {
        var steak = DraftItem(name: "Steak", category: .meatRaw, addedDate: date(2026, 9, 20), calculator: calculator)
        steak.expiryDate = date(2026, 9, 21)
        steak.expiryEdited = true
        steak.freeze(on: date(2026, 9, 20), calculator: calculator)
        #expect(!steak.expiryEdited)
        #expect(steak.expiryDate == date(2027, 1, 18))
    }

    @Test func purchaseDateDoesntMoveHomeFrozenDate() {
        var steak = DraftItem(name: "Steak", category: .meatRaw, addedDate: date(2026, 9, 20), calculator: calculator)
        steak.freeze(on: date(2026, 9, 22), calculator: calculator)
        steak.setAddedDate(date(2026, 9, 18), calculator: calculator)
        #expect(steak.frozenDate == date(2026, 9, 22))
    }

    @Test func warnsAboutExpiredAndPoorFreezingFood() {
        let frozenOn = date(2026, 9, 28)
        #expect(calculator.freezeWarnings(for: .meatRaw, named: "Steak", expiringOn: date(2026, 9, 28), frozenOn: frozenOn).isEmpty)
        #expect(
            calculator.freezeWarnings(for: .meatRaw, named: "Steak", expiringOn: date(2026, 9, 25), frozenOn: frozenOn)
                == ["This expired on Sep 25. Freezing won't make it safe to eat."]
        )
        #expect(calculator.freezeWarnings(for: .produceLeafy, named: "Romaine", expiringOn: nil, frozenOn: frozenOn).count == 1)
        #expect(calculator.freezeWarnings(for: .produceLeafy, named: "Romaine", expiringOn: date(2026, 9, 1), frozenOn: frozenOn).count == 2)
    }

    @Test func frozenDateCantComeBeforePurchase() {
        var steak = DraftItem(name: "Steak", category: .meatRaw, addedDate: date(2026, 9, 20), calculator: calculator)
        steak.freeze(on: date(2026, 9, 22), calculator: calculator)
        steak.setAddedDate(date(2026, 9, 25), calculator: calculator)
        #expect(steak.frozenDate == date(2026, 9, 25))
        #expect(steak.expiryDate == date(2027, 1, 23))
    }

    @Test func unfreezingCountsFromPurchaseNotAThaw() {
        var steak = DraftItem(name: "Steak", category: .meatRaw, addedDate: date(2026, 9, 20), location: .freezer, calculator: calculator)
        steak.unfreeze(modes: StorageModes(freezer: true), calculator: calculator)
        #expect(steak.location == .fridge)
        #expect(steak.frozenDate == nil)
        #expect(steak.thawedDate == nil)
        #expect(steak.expiryDate == date(2026, 9, 23))

        var bread = DraftItem(name: "Bread", category: .breadBakery, addedDate: date(2026, 9, 20), location: .freezer, calculator: calculator)
        bread.unfreeze(modes: StorageModes(pantry: true, freezer: true), calculator: calculator)
        #expect(bread.location == .pantry)
        #expect(bread.expiryDate == date(2026, 9, 25))
    }

    @Test func freezerFoodTableBeatsCategory() {
        var beef = DraftItem(name: "Ground Beef", category: .meatRaw, addedDate: date(2026, 9, 20), calculator: calculator)
        beef.freeze(on: date(2026, 9, 20), calculator: calculator)
        #expect(beef.expiryDate == date(2026, 12, 19))
    }

    @Test func thawedMeatUsesUSDALimit() {
        var steak = DraftItem(name: "Steak", category: .meatRaw, addedDate: date(2026, 9, 20), calculator: calculator)
        steak.freeze(on: date(2026, 9, 20), calculator: calculator)
        steak.thaw(on: date(2026, 11, 1), modes: StorageModes(freezer: true), calculator: calculator)
        #expect(steak.location == .fridge)
        #expect(steak.frozenDate == nil)
        #expect(steak.thawedDate == date(2026, 11, 1))
        #expect(steak.expiryDate == date(2026, 11, 4))
    }

    @Test func thawedFoodTableBeatsCategory() {
        var beef = DraftItem(name: "Ground Beef", category: .meatRaw, addedDate: date(2026, 9, 20), calculator: calculator)
        beef.freeze(on: date(2026, 9, 20), calculator: calculator)
        beef.thaw(on: date(2026, 11, 1), modes: StorageModes(freezer: true), calculator: calculator)
        #expect(beef.expiryDate == date(2026, 11, 2))
    }

    @Test(arguments: [(true, StorageLocation.pantry, 2026, 11, 6), (false, .fridge, 2026, 11, 15)])
    func thawedBreadGoesBackToItsUsualPlace(pantry: Bool, location: StorageLocation, year: Int, month: Int, day: Int) {
        var bread = DraftItem(name: "Bread", category: .breadBakery, addedDate: date(2026, 9, 20), location: .freezer, calculator: calculator)
        bread.thaw(on: date(2026, 11, 1), modes: StorageModes(pantry: pantry, freezer: true), calculator: calculator)
        #expect(bread.location == location)
        #expect(bread.expiryDate == date(year, month, day))
    }

    @Test func thawedFrozenMealGoesToFridge() {
        var pizza = DraftItem(name: "Pizza", category: .frozenMeals, addedDate: date(2026, 9, 20), location: .freezer, calculator: calculator)
        pizza.thaw(on: date(2026, 11, 1), modes: StorageModes(pantry: true, freezer: true), calculator: calculator)
        #expect(pizza.location == .fridge)
        #expect(pizza.expiryDate == date(2026, 11, 4))
    }

    @Test func refreezingClearsThawedDate() {
        var steak = DraftItem(name: "Steak", category: .meatRaw, addedDate: date(2026, 9, 20), location: .freezer, calculator: calculator)
        steak.thaw(on: date(2026, 11, 1), modes: StorageModes(freezer: true), calculator: calculator)
        steak.freeze(on: date(2026, 11, 2), calculator: calculator)
        #expect(steak.thawedDate == nil)
        #expect(steak.frozenDate == date(2026, 11, 2))
        #expect(steak.expiryDate == date(2027, 3, 2))
    }

    @Test func savedFrozenAndThawedItemsArentHandPicked() {
        let frozen = FridgeItem(
            name: "Steak", category: .meatRaw, addedDate: date(2026, 9, 20), expiryDate: date(2027, 1, 20),
            location: .freezer, frozenDate: date(2026, 9, 22)
        )
        let thawed = FridgeItem(
            name: "Steak", category: .meatRaw, addedDate: date(2026, 9, 20), expiryDate: date(2026, 11, 4),
            thawedDate: date(2026, 11, 1)
        )
        #expect(!DraftItem(frozen, calculator: calculator).expiryEdited)
        #expect(!DraftItem(thawed, calculator: calculator).expiryEdited)
    }

    @Test func savesAndAppliesStorageFields() {
        var steak = DraftItem(name: "Steak", category: .meatRaw, addedDate: date(2026, 9, 20), calculator: calculator)
        steak.freeze(on: date(2026, 9, 22), calculator: calculator)
        let item = FridgeItem(steak)
        #expect(item.location == .freezer)
        #expect(item.frozenDate == date(2026, 9, 22))
        #expect(item.thawedDate == nil)

        var draft = DraftItem(item, calculator: calculator)
        draft.thaw(on: date(2026, 11, 1), modes: StorageModes(freezer: true), calculator: calculator)
        item.apply(draft)
        #expect(item.location == .fridge)
        #expect(item.frozenDate == nil)
        #expect(item.thawedDate == date(2026, 11, 1))
        #expect(item.expiryDate == date(2026, 11, 4))
    }

    @Test func remembersFreezerDaysFromTheFreezeDay() async {
        await withTemporaryMemory { memory in
            let calculator = ExpiryCalculator.testing(shelfLife: self.calculator.shelfLife, memory: memory)
            var steak = DraftItem(name: "Steak", category: .meatRaw, addedDate: date(2026, 9, 20), calculator: calculator)
            steak.freeze(on: date(2026, 9, 22), calculator: calculator)
            steak.expiryDate = date(2026, 12, 21)
            calculator.remember(steak)
            #expect(memory.days(for: "Steak", in: .freezer) == 90)
            #expect(memory.days(for: "Steak") == nil)
        }
    }

    @Test func doesntRememberThawedItems() async {
        await withTemporaryMemory { memory in
            let calculator = ExpiryCalculator.testing(shelfLife: self.calculator.shelfLife, memory: memory)
            var steak = DraftItem(name: "Steak", category: .meatRaw, addedDate: date(2026, 9, 20), location: .freezer, calculator: calculator)
            steak.thaw(on: date(2026, 11, 1), modes: StorageModes(freezer: true), calculator: calculator)
            steak.expiryDate = date(2026, 11, 10)
            calculator.remember(steak)
            #expect(memory.days(for: "Steak") == nil)
        }
    }
}
