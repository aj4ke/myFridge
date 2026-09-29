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

    @Test func missingOtherFallsBackToAWeek() {
        #expect(ShelfLifeService(daysByCategory: [:]).days(for: .dairyMilk) == 7)
    }

    @Test(arguments: [StorageLocation.pantry, .freezer])
    func everyAllowedCategoryHasAValue(in location: StorageLocation) {
        let table = ShelfLifeService.shared.daysByLocation[location] ?? [:]
        for category in FoodCategory.allCases where category.allowedLocations.contains(location) {
            #expect((table[category.rawValue] ?? 0) > 0, "\(location) table is missing \(category.rawValue)")
        }
    }

    @Test func bundledStorageTablesHaveNoUnknownKeys() {
        let service = ShelfLifeService.shared
        let keys = service.daysByLocation.values.flatMap(\.keys) + Array(service.thawedDaysByCategory.keys)
        for key in keys {
            #expect(FoodCategory(rawValue: key) != nil, "unknown category key \(key)")
        }
    }

    @Test func pantryTableOnlyHasPantryCategories() {
        for key in (ShelfLifeService.shared.daysByLocation[.pantry] ?? [:]).keys {
            #expect(FoodCategory(rawValue: key)?.allowedLocations.contains(.pantry) == true, "\(key) can't go in the pantry")
        }
    }

    @Test func eachLocationUsesItsOwnTable() {
        let service = ShelfLifeService(daysByLocation: [
            .fridge: ["meat_raw": 3],
            .freezer: ["meat_raw": 120, "other": 60],
        ])
        #expect(service.days(for: .meatRaw) == 3)
        #expect(service.days(for: .meatRaw, in: .freezer) == 120)
        #expect(service.days(for: .eggs, in: .freezer) == 60)
        #expect(service.days(for: .eggs, in: .pantry) == 7)
    }

    @Test func onlyLimitedCategoriesHaveThawedDays() {
        let service = ShelfLifeService(daysByLocation: [:], thawedDaysByCategory: ["poultry_raw": 1])
        #expect(service.thawedDays(for: .poultryRaw) == 1)
        #expect(service.thawedDays(for: .breadBakery) == nil)
    }
}
