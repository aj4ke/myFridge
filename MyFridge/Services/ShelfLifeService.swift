import Foundation

nonisolated struct ShelfLifeService {
    static let shared = ShelfLifeService(bundle: .main)

    let daysByLocation: [StorageLocation: [String: Int]]
    let thawedDaysByCategory: [String: Int]

    var daysByCategory: [String: Int] {
        daysByLocation[.fridge] ?? [:]
    }

    init(daysByLocation: [StorageLocation: [String: Int]], thawedDaysByCategory: [String: Int] = [:]) {
        self.daysByLocation = daysByLocation
        self.thawedDaysByCategory = thawedDaysByCategory
    }

    init(daysByCategory: [String: Int]) {
        self.init(daysByLocation: [.fridge: daysByCategory])
    }

    init(bundle: Bundle) {
        self.init(
            daysByLocation: [
                .fridge: Self.table("shelf_life", in: bundle),
                .pantry: Self.table("pantry_shelf_life", in: bundle),
                .freezer: Self.table("freezer_shelf_life", in: bundle),
            ],
            thawedDaysByCategory: Self.table("thawed_shelf_life", in: bundle)
        )
    }

    private static func table(_ name: String, in bundle: Bundle) -> [String: Int] {
        let url = bundle.url(forResource: name, withExtension: "json")!
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode([String: Int].self, from: data)
    }

    func days(for category: FoodCategory, in location: StorageLocation = .fridge) -> Int {
        let table = daysByLocation[location] ?? [:]
        return table[category.rawValue] ?? table[FoodCategory.other.rawValue] ?? 7
    }

    /** Only categories with a USDA limit after thawing have one. */
    func thawedDays(for category: FoodCategory) -> Int? {
        thawedDaysByCategory[category.rawValue]
    }
}
