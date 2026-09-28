import Foundation

nonisolated struct ShelfLifeMemory {
    static let shared = ShelfLifeMemory(suiteName: nil)
    static let key = "learnedShelfLife"

    let suiteName: String?

    private var defaults: UserDefaults {
        suiteName.map { UserDefaults(suiteName: $0)! } ?? .standard
    }

    func days(for name: String) -> Int? {
        (defaults.dictionary(forKey: Self.key) as? [String: Int])?[FoodShelfLife.normalized(name)]
    }

    func remember(_ days: Int, for name: String) {
        var learned = defaults.dictionary(forKey: Self.key) as? [String: Int] ?? [:]
        learned[FoodShelfLife.normalized(name)] = days
        defaults.set(learned, forKey: Self.key)
    }
}
