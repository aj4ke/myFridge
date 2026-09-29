import Foundation

/**
 * Days are the low end of USDA FoodKeeper times for each location.
 * A food only matches items in its group's categories, so produce "onion" doesn't match onion dip.
 */
nonisolated struct FoodShelfLife {
    static let shared = FoodShelfLife(bundle: .main)

    struct Group: Decodable {
        let categories: [String]
        let foods: [String: Int]
    }

    let groupsByLocation: [StorageLocation: [Group]]
    let thawedGroups: [Group]

    var groups: [Group] {
        groupsByLocation[.fridge] ?? []
    }

    init(groupsByLocation: [StorageLocation: [Group]], thawedGroups: [Group] = []) {
        self.groupsByLocation = groupsByLocation
        self.thawedGroups = thawedGroups
    }

    init(groups: [Group]) {
        self.init(groupsByLocation: [.fridge: groups])
    }

    init(bundle: Bundle) {
        self.init(
            groupsByLocation: [
                .fridge: Self.groups("food_shelf_life", in: bundle),
                .pantry: Self.groups("pantry_food_shelf_life", in: bundle),
                .freezer: Self.groups("freezer_food_shelf_life", in: bundle),
            ],
            thawedGroups: Self.groups("thawed_food_shelf_life", in: bundle)
        )
    }

    private static func groups(_ name: String, in bundle: Bundle) -> [Group] {
        let url = bundle.url(forResource: name, withExtension: "json")!
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode([Group].self, from: data)
    }

    func days(for name: String, category: FoodCategory, in location: StorageLocation = .fridge) -> Int? {
        Self.days(for: name, category: category, in: groupsByLocation[location] ?? [])
    }

    func thawedDays(for name: String, category: FoodCategory) -> Int? {
        Self.days(for: name, category: category, in: thawedGroups)
    }

    /**
     * Matches whole words and plurals. The longest food wins ("green onion" over "onion"),
     * and ties go to the shorter shelf life.
     */
    private static func days(for name: String, category: FoodCategory, in groups: [Group]) -> Int? {
        let padded = " \(normalized(name)) "
        let matches = groups
            .filter { $0.categories.contains(category.rawValue) }
            .flatMap(\.foods)
            .filter { food, _ in forms(of: food).contains { padded.contains(" \($0) ") } }
        return matches.max { a, b in (a.key.count, b.value) < (b.key.count, a.value) }?.value
    }

    /** From USDA's list of foods that don't freeze well. They stay safe but turn limp, mushy or watery. */
    static let poorFreezers = [
        "lettuce", "romaine", "iceberg", "spring mix", "salad", "endive", "cress", "cucumber", "radish",
        "sour cream", "mayo", "mayonnaise", "dressing", "custard", "meringue", "gelatin",
        "soda", "beer", "sparkling water", "seltzer",
    ]

    /** Eggs in the shell crack when frozen. Separated or liquid eggs freeze fine. */
    static func freezesPoorly(_ category: FoodCategory, named name: String) -> Bool {
        if category == .eggs {
            return !["egg white", "yolk", "liquid egg", "egg substitute"].contains { mentions($0, in: name) }
        }
        return poorFreezers.contains { mentions($0, in: name) }
    }

    static func mentions(_ food: String, in name: String) -> Bool {
        let padded = " \(normalized(name)) "
        return forms(of: food).contains { padded.contains(" \($0) ") }
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
