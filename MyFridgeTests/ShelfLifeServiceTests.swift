import Testing
@testable import MyFridge

struct ShelfLifeServiceTests {
    @Test func everyCategoryHasAValueInBundledJSON() {
        let table = ShelfLifeService.shared.daysByCategory
        for category in FoodCategory.allCases {
            let days = table[category.rawValue]
            #expect(days != nil, "shelf_life.json is missing \(category.rawValue)")
            #expect((days ?? 0) > 0, "\(category.rawValue) should be positive")
        }
    }

    @Test func bundledJSONHasNoUnknownKeys() {
        for key in ShelfLifeService.shared.daysByCategory.keys {
            #expect(FoodCategory(rawValue: key) != nil, "shelf_life.json has unknown key \(key)")
        }
    }

    @Test func returnsValueForKnownKey() {
        let service = ShelfLifeService(daysByCategory: ["eggs": 28, "other": 7])
        #expect(service.days(for: .eggs) == 28)
    }

    @Test func missingKeyFallsBackToOther() {
        let service = ShelfLifeService(daysByCategory: ["eggs": 28, "other": 9])
        #expect(service.days(for: .dairyMilk) == 9)
    }
}
