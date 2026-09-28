import Foundation

nonisolated struct ShelfLifeService {
    static let shared = ShelfLifeService(bundle: .main)

    let daysByCategory: [String: Int]

    init(daysByCategory: [String: Int]) {
        self.daysByCategory = daysByCategory
    }

    init(bundle: Bundle) {
        let url = bundle.url(forResource: "shelf_life", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        self.init(daysByCategory: try! JSONDecoder().decode([String: Int].self, from: data))
    }

    func days(for category: FoodCategory) -> Int {
        daysByCategory[category.rawValue] ?? daysByCategory[FoodCategory.other.rawValue] ?? 7
    }
}
