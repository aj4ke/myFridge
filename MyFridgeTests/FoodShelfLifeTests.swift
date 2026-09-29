import Testing
@testable import MyFridge

struct FoodShelfLifeTests {
    let bundledGroups = FoodShelfLife.shared.groupsByLocation.values.flatMap { $0 } + FoodShelfLife.shared.thawedGroups

    @Test func bundledGroupsUseRealCategories() {
        for group in bundledGroups {
            for category in group.categories {
                #expect(FoodCategory(rawValue: category) != nil, "food table has unknown category \(category)")
            }
        }
    }

    @Test func bundledFoodsAreNormalizedAndPositive() {
        for (food, days) in bundledGroups.flatMap(\.foods) {
            #expect(FoodShelfLife.normalized(food) == food, "\(food) should be plain lowercase words")
            #expect(days > 0, "\(food) should be positive")
        }
    }

    @Test(arguments: [
        ("Organic Red Onion", FoodCategory.produceOther, 60 as Int?),
        ("ORG RED ONION", .produceOther, 60),
        ("Green Onions", .produceOther, 7),
        ("Brussels Sprouts", .produceOther, 3),
        ("Organic Strawberries", .produceBerries, 2),
        ("Radishes", .produceOther, 10),
        ("Cherry Tomatoes", .produceOther, 5),
        ("Prickly Pear", .fruitWhole, 7),
        ("Pineapple Chunks Small", .fruitWhole, 5),
        ("Hard-Boiled Eggs", .eggs, 7),
        ("Whipped Cream Cheese", .cheeseSoft, 14),
        ("80/20 Ground Beef", .meatRaw, 13),
        ("Ground Turkey", .poultryRaw, 1),
        ("French Onion Dip", .condiments, 14),
        ("Grapefruit", .fruitWhole, nil),
        ("Buttermilk", .dairyMilk, nil),
        ("Strawberry Yogurt", .dairyYogurt, nil),
        ("Olive Oil", .condiments, nil),
        ("Atlantic Salmon", .seafoodRaw, nil),
    ])
    func findsFoodInName(_ name: String, category: FoodCategory, days: Int?) {
        #expect(FoodShelfLife.shared.days(for: name, category: category) == days)
    }

    @Test(arguments: [
        ("Cherries", 2 as Int?),
        ("Peaches", 3),
        ("Carrots", 14),
        ("Organic Baby Carrots", 28),
        ("Peanut Butter", nil),
        ("", nil),
    ])
    func matchesPluralsAndWholeWordsOnly(_ name: String, days: Int?) {
        let table = FoodShelfLife(groups: [
            .init(categories: ["other"], foods: ["cherry": 2, "peach": 3, "carrot": 14, "baby carrot": 28, "pea": 3]),
        ])
        #expect(table.days(for: name, category: .other) == days)
    }

    @Test func onlyMatchesFoodsInTheItemsCategory() {
        let table = FoodShelfLife(groups: [.init(categories: ["produce_other"], foods: ["onion": 60])])
        #expect(table.days(for: "Onion", category: .produceOther) == 60)
        #expect(table.days(for: "Onion", category: .condiments) == nil)
    }

    @Test func tieGoesToShorterShelfLife() {
        let table = FoodShelfLife(groups: [.init(categories: ["other"], foods: ["kale": 5, "leek": 9])])
        #expect(table.days(for: "Kale and Leek Mix", category: .other) == 5)
    }

    @Test(arguments: [
        ("Russet Potatoes", FoodCategory.produceOther, StorageLocation.pantry, 30 as Int?),
        ("Green Onions", .produceOther, .pantry, 3),
        ("Sandwich Bread", .breadBakery, .pantry, 14),
        ("Flour Tortillas", .breadBakery, .pantry, 90),
        ("Corn Tortillas", .grainsPasta, .pantry, 25),
        ("Extra Virgin Olive Oil", .bakingSpices, .pantry, 180),
        ("80/20 Ground Beef", .meatRaw, .freezer, 90),
        ("Whole Chicken", .poultryRaw, .freezer, 360),
        ("Atlantic Salmon", .seafoodRaw, .freezer, 60),
        ("Wild Cod Fillets", .seafoodRaw, .freezer, 180),
        ("Crinkle Cut French Fries", .frozenMeals, .freezer, 360),
        ("Frozen Waffles", .frozenMeals, .freezer, 90),
        ("Sandwich Bread", .breadBakery, .freezer, 90),
        ("Ground Beef", .meatRaw, .fridge, 13),
    ])
    func findsFoodInEachLocation(_ name: String, category: FoodCategory, location: StorageLocation, days: Int?) {
        #expect(FoodShelfLife.shared.days(for: name, category: category, in: location) == days)
    }

    @Test func thawedTableCoversGroundMeat() {
        #expect(FoodShelfLife.shared.thawedDays(for: "80/20 Ground Beef", category: .meatRaw) == 1)
        #expect(FoodShelfLife.shared.thawedDays(for: "Ribeye Steak", category: .meatRaw) == nil)
    }

    @Test func onlyMatchesFoodsInTheItemsLocation() {
        let table = FoodShelfLife(groupsByLocation: [.pantry: [.init(categories: ["produce_other"], foods: ["onion": 30])]])
        #expect(table.days(for: "Onion", category: .produceOther, in: .pantry) == 30)
        #expect(table.days(for: "Onion", category: .produceOther) == nil)
    }

    @Test(arguments: [
        ("Romaine Hearts", FoodCategory.produceLeafy, true),
        ("Organic Spring Mix", .produceLeafy, true),
        ("English Cucumber", .produceOther, true),
        ("Chicken Salad", .preparedMeals, true),
        ("Large Brown Eggs", .eggs, true),
        ("Hard-Boiled Eggs", .eggs, true),
        ("Liquid Egg Whites", .eggs, false),
        ("Baby Spinach", .produceLeafy, false),
        ("Chicken Thighs", .poultryRaw, false),
        ("Mayo", .condiments, true),
    ])
    func flagsFoodsThatFreezePoorly(_ name: String, category: FoodCategory, expected: Bool) {
        #expect(FoodShelfLife.freezesPoorly(category, named: name) == expected)
    }

    @Test func normalizesNames() {
        #expect(FoodShelfLife.normalized("  Jalapeño  Peppers, 2-Pack! ") == "jalapeno peppers 2 pack")
    }
}
