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

    @Test func onlyMeatCategoriesTrackWeight() {
        let tracked = FoodCategory.allCases.filter(\.tracksWeight)
        #expect(Set(tracked) == [.meatRaw, .poultryRaw, .seafoodRaw, .meatDeli])
    }
}
