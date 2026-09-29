import Foundation

nonisolated struct ShelfLifeMemory {
    static let shared = ShelfLifeMemory(suiteName: nil)
    static let key = "learnedShelfLife"

    let suiteName: String?

    private var defaults: UserDefaults {
        suiteName.map { UserDefaults(suiteName: $0)! } ?? .standard
    }

    /** The fridge keeps the original key so shelf lives learned before pantry and freezer existed still apply. */
    static func storageKey(for location: StorageLocation) -> String {
        location == .fridge ? key : "\(key).\(location.rawValue)"
    }

    func days(for name: String, in location: StorageLocation = .fridge) -> Int? {
        (defaults.dictionary(forKey: Self.storageKey(for: location)) as? [String: Int])?[FoodShelfLife.normalized(name)]
    }

    func remember(_ days: Int, for name: String, in location: StorageLocation = .fridge) {
        let key = Self.storageKey(for: location)
        var learned = defaults.dictionary(forKey: key) as? [String: Int] ?? [:]
        learned[FoodShelfLife.normalized(name)] = days
        defaults.set(learned, forKey: key)
    }
}
