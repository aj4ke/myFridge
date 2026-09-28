import Foundation

/**
 * Days are the low end of USDA FoodKeeper fridge times.
 * A food only matches items in its group's categories, so produce "onion" doesn't match onion dip.
 */
nonisolated struct FoodShelfLife {
    static let shared = FoodShelfLife(bundle: .main)

    struct Group: Decodable {
        let categories: [String]
        let foods: [String: Int]
    }

    let groups: [Group]

    init(groups: [Group]) {
        self.groups = groups
    }

    init(bundle: Bundle) {
        let url = bundle.url(forResource: "food_shelf_life", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        self.init(groups: try! JSONDecoder().decode([Group].self, from: data))
    }

    /**
     * Matches whole words and plurals. The longest food wins ("green onion" over "onion"),
     * and ties go to the shorter shelf life.
     */
    func days(for name: String, category: FoodCategory) -> Int? {
        let padded = " \(Self.normalized(name)) "
        let matches = groups
            .filter { $0.categories.contains(category.rawValue) }
            .flatMap(\.foods)
            .filter { food, _ in Self.forms(of: food).contains { padded.contains(" \($0) ") } }
        return matches.max { a, b in (a.key.count, b.value) < (b.key.count, a.value) }?.value
    }

    static func normalized(_ name: String) -> String {
        String(name.lowercased().folding(options: .diacriticInsensitive, locale: nil).map { $0.isLetter || $0.isNumber ? $0 : " " })
            .split(separator: " ")
            .joined(separator: " ")
    }

    static func forms(of food: String) -> [String] {
        var forms = [food, food + "s", food + "es"]
        if food.hasSuffix("y") {
            forms.append(String(food.dropLast()) + "ies")
        }
        return forms
    }
}
