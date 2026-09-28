import Foundation
import Testing
@testable import MyFridge

struct ExpiryCalculatorTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    var calculator: ExpiryCalculator {
        ExpiryCalculator(
            shelfLife: ShelfLifeService(daysByCategory: ["dairy_milk": 7, "poultry_raw": 2, "eggs": 28, "other": 7]),
            calendar: calendar
        )
    }

    func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func addsShelfLifeDays() {
        #expect(calculator.expiry(for: .dairyMilk, addedOn: date(2026, 9, 10)) == date(2026, 9, 17))
    }

    @Test func returnsStartOfDayRegardlessOfTimeAdded() {
        #expect(calculator.expiry(for: .dairyMilk, addedOn: date(2026, 9, 10, hour: 23, minute: 45)) == date(2026, 9, 17))
    }

    @Test func missingCategoryUsesOther() {
        #expect(calculator.expiry(for: .herbs, addedOn: date(2026, 9, 10)) == date(2026, 9, 17))
    }

    @Test func crossesMonthBoundary() {
        #expect(calculator.expiry(for: .dairyMilk, addedOn: date(2026, 9, 28)) == date(2026, 10, 5))
        #expect(calculator.expiry(for: .poultryRaw, addedOn: date(2026, 1, 31)) == date(2026, 2, 2))
    }

    @Test func crossesYearBoundary() {
        #expect(calculator.expiry(for: .dairyMilk, addedOn: date(2026, 12, 29)) == date(2027, 1, 5))
    }

    @Test func handlesFebruary() {
        #expect(calculator.expiry(for: .poultryRaw, addedOn: date(2026, 2, 27)) == date(2026, 3, 1))
        #expect(calculator.expiry(for: .poultryRaw, addedOn: date(2028, 2, 27)) == date(2028, 2, 29))
        #expect(calculator.expiry(for: .eggs, addedOn: date(2028, 2, 1)) == date(2028, 2, 29))
    }

    @Test func handlesDaylightSavingChanges() {
        #expect(calculator.expiry(for: .dairyMilk, addedOn: date(2026, 10, 29)) == date(2026, 11, 5))
        #expect(calculator.expiry(for: .dairyMilk, addedOn: date(2027, 3, 10)) == date(2027, 3, 17))
    }

    @Test(arguments: [
        (-30, ExpiryStatus.expired),
        (-1, .expired),
        (0, .soon),
        (1, .soon),
        (2, .soon),
        (3, .fresh),
        (30, .fresh),
    ])
    func statusThresholds(daysLeft: Int, expected: ExpiryStatus) {
        let now = date(2026, 9, 23, hour: 12)
        let expiry = calendar.date(byAdding: .day, value: daysLeft, to: date(2026, 9, 23))!
        #expect(calculator.status(for: expiry, now: now) == expected)
    }

    @Test func expiryDayStaysSoonUntilMidnight() {
        let expiry = date(2026, 9, 23)
        #expect(calculator.status(for: expiry, now: date(2026, 9, 23, hour: 23, minute: 59)) == .soon)
        #expect(calculator.status(for: expiry, now: date(2026, 9, 24, hour: 0, minute: 1)) == .expired)
    }

    @Test func freshBecomesSoonAtStartOfDay() {
        let expiry = date(2026, 9, 26)
        #expect(calculator.status(for: expiry, now: date(2026, 9, 23, hour: 23, minute: 59)) == .fresh)
        #expect(calculator.status(for: expiry, now: date(2026, 9, 24, hour: 0, minute: 1)) == .soon)
    }

    @Test func statusAcrossMonthBoundary() {
        #expect(calculator.status(for: date(2026, 10, 1), now: date(2026, 9, 30, hour: 9)) == .soon)
        #expect(calculator.status(for: date(2026, 9, 30), now: date(2026, 10, 1, hour: 9)) == .expired)
    }

    @Test(arguments: [
        (-3, "Expired 3 days ago"),
        (-1, "Expired yesterday"),
        (0, "Expires today"),
        (1, "Expires tomorrow"),
        (2, "2 days left"),
    ])
    func relativeText(daysLeft: Int, expected: String) {
        let now = date(2026, 9, 23, hour: 12)
        let expiry = calendar.date(byAdding: .day, value: daysLeft, to: date(2026, 9, 23))!
        #expect(calculator.relativeText(for: expiry, now: now) == expected)
    }

    @Test func memoryBeatsFoodTableBeatsCategory() async {
        await withTemporaryMemory { memory in
            var calculator = self.calculator
            calculator.foods = FoodShelfLife(groups: [.init(categories: ["other"], foods: ["onion": 60])])
            calculator.memory = memory
            #expect(calculator.days(for: .other, named: "Garlic") == 7)
            #expect(calculator.days(for: .other, named: "Red Onion") == 60)
            memory.remember(45, for: "Red Onion")
            #expect(calculator.days(for: .other, named: "Red Onion") == 45)
            #expect(calculator.expiry(for: .other, named: "Red Onion", addedOn: date(2026, 9, 10)) == date(2026, 10, 25))
        }
    }

    @Test func remembersDaysFromPurchaseToExpiry() async {
        await withTemporaryMemory { memory in
            var calculator = self.calculator
            calculator.memory = memory
            var draft = DraftItem(name: "Organic Milk", category: .dairyMilk, addedDate: date(2026, 9, 21), calculator: calculator)
            draft.expiryDate = date(2026, 11, 11)
            calculator.remember(draft)
            #expect(memory.days(for: "Organic Milk") == 51)
        }
    }

    /** Package dates from a September 28, 2026 order. Repeated names use another category the model has picked for them. */
    @Test(arguments: [
        ("Ground Beef", FoodCategory.meatRaw, 2026, 10, 11),
        ("Organic Pork Bacon", .meatRaw, 2026, 12, 15),
        ("Organic Pork Bacon", .meatDeli, 2026, 12, 15),
        ("Mexican Style Blend Shredded Cheese", .cheeseHard, 2027, 1, 31),
        ("Organic Mexican Style Blend Shredded Cheese", .cheeseSoft, 2027, 1, 31),
        ("Boneless Skinless Chicken Thighs", .poultryRaw, 2026, 10, 14),
        ("Chipotle Peppers", .condiments, 2027, 11, 19),
        ("Chipotle Peppers", .produceOther, 2027, 11, 19),
        ("Chipotle Peppers in Adobo Sauce", .condiments, 2027, 11, 19),
        ("White Flour Burrito Wraps", .other, 2026, 10, 31),
        ("White Flour Burrito Wraps", .produceOther, 2026, 10, 31),
        ("Flour Tortillas", .other, 2026, 10, 31),
        ("Brioche Hamburger Bun", .other, 2026, 10, 11),
        ("Organic Whole Milk", .dairyMilkUltra, 2026, 11, 16),
    ])
    func matchesPackageDates(name: String, category: FoodCategory, year: Int, month: Int, day: Int) {
        let calculator = ExpiryCalculator(memory: ShelfLifeMemory(suiteName: "MyFridgeTests.empty"), calendar: calendar)
        #expect(calculator.expiry(for: category, named: name, addedOn: date(2026, 9, 28)) == date(year, month, day))
    }
}
