import Foundation
import FoundationModels

nonisolated protocol ItemParser {
    func parse(lines: [String], source: ItemSource) async throws -> ParseResult
}

nonisolated struct ParseResult {
    var items: [ParsedItem]
    var skippedLines: [String] = []
}

@Generable
nonisolated struct ParsedReceipt {
    @Guide(description: "Grocery items found in the text")
    var items: [ParsedItem]
}

/** line is 1-based and used to find the item's weight in the filtered lines. */
@Generable
nonisolated struct ParsedItem {
    @Guide(description: "The number in square brackets at the start of the input line this product came from")
    var line: Int

    @Guide(description: "Plain readable product name with receipt abbreviations expanded and without store brand or package size, e.g. 'Organic Baby Spinach'")
    var name: String

    /** Comes before category so the model decides where it's kept first, then picks a category that fits. */
    @Guide(description: "Where this is kept at home, following the storage rules")
    var storage: ParsedStorage

    @Guide(description: "Closest category. Chicken and turkey are poultryRaw. Fish and shrimp are seafoodRaw. Beef, pork, lamb, bacon and sausage are meatRaw, even when frozen. meatDeli is only sliced deli meat. Butter is other. Fruit that isn't berries is fruitWhole. Bread, buns, bagels, tortillas and wraps are breadBakery. Pasta, rice and dry beans are grainsPasta. Chips, crackers and cereal are snacksCereal. Canned soup, canned peppers and jarred food are cannedGoods. Flour, sugar, oil and spices are bakingSpices. Waffles, frozen pizza, fries and frozen dinners are frozenMeals. Frozen fruit and vegetables are frozenProduce. Ice cream is frozenDesserts. Fresh soups and ready meals are preparedMeals. Household goods are other.")
    var category: FoodCategory

    @Guide(description: "Number of units purchased", .range(1...24))
    var quantity: Int
}

@Generable
nonisolated enum ParsedStorage {
    case fridge
    case pantry
    case freezer
    case notFood

    var location: StorageLocation? {
        switch self {
        case .fridge: .fridge
        case .pantry: .pantry
        case .freezer: .freezer
        case .notFood: nil
        }
    }
}
