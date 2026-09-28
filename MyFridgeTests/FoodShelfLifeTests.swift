import Testing
@testable import MyFridge

struct FoodShelfLifeTests {
    @Test func bundledGroupsUseRealCategories() {
        for group in FoodShelfLife.shared.groups {
            for category in group.categories {
                #expect(FoodCategory(rawValue: category) != nil, "food_shelf_life.json has unknown category \(category)")
            }
        }
    }

    @Test func bundledFoodsAreNormalizedAndPositive() {
        for (food, days) in FoodShelfLife.shared.groups.flatMap(\.foods) {
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

    @Test func tieGoesToShorterShelfLife() {
        let table = FoodShelfLife(groups: [.init(categories: ["other"], foods: ["kale": 5, "leek": 9])])
        #expect(table.days(for: "Kale and Leek Mix", category: .other) == 5)
    }

    @Test func normalizesNames() {
        #expect(FoodShelfLife.normalized("  Jalapeño  Peppers, 2-Pack! ") == "jalapeno peppers 2 pack")
    }
}
