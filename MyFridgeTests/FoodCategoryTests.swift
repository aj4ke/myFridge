import Testing
import UIKit
@testable import MyFridge

struct FoodCategoryTests {
    @Test(arguments: FoodCategory.allCases)
    func symbolExists(_ category: FoodCategory) {
        #expect(UIImage(systemName: category.symbolName) != nil, "\(category.symbolName) isn't an SF Symbol")
    }

    @Test func displayNamesAreUnique() {
        #expect(Set(FoodCategory.allCases.map(\.displayName)).count == FoodCategory.allCases.count)
    }

    /** The subcategory Picker uses the names as ForEach ids. */
    @Test(arguments: FoodCategory.allCases)
    func subcategoriesAreUnique(_ category: FoodCategory) {
        #expect(Set(category.subcategories).count == category.subcategories.count)
    }

    @Test(arguments: FoodCategory.allCases)
    func defaultLocationIsAllowedAndEverythingCanFreeze(_ category: FoodCategory) {
        #expect(category.allowedLocations.contains(category.defaultLocation))
        #expect(category.allowedLocations.contains(.freezer))
    }

    @Test func perishablesCantGoInThePantry() {
        for category in [FoodCategory.meatRaw, .poultryRaw, .seafoodRaw, .dairyMilk, .eggs, .leftovers] {
            #expect(!category.allowedLocations.contains(.pantry), "\(category)")
        }
    }

    @Test(arguments: [
        (FoodCategory.breadBakery, true, StorageLocation.pantry),
        (.breadBakery, false, .fridge),
        (.frozenMeals, true, .fridge),
        (.meatRaw, true, .fridge),
        (.fruitWhole, true, .fridge),
    ])
    func thawsBackToItsUsualPlace(_ category: FoodCategory, pantry: Bool, expected: StorageLocation) {
        #expect(category.thawDestination(StorageModes(pantry: pantry, freezer: true)) == expected)
    }

    @Test(arguments: StorageLocation.allCases)
    func locationSymbolExists(_ location: StorageLocation) {
        #expect(UIImage(systemName: location.symbolName) != nil, "\(location.symbolName) isn't an SF Symbol")
    }

    @Test func onlyMeatCategoriesTrackWeight() {
        let tracked = FoodCategory.allCases.filter(\.tracksWeight)
        #expect(Set(tracked) == [.meatRaw, .poultryRaw, .seafoodRaw, .meatDeli])
    }
}
