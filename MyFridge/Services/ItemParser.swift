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

    @Guide(description: "Closest category. Chicken and turkey are poultryRaw. Fish and shrimp are seafoodRaw. Beef, pork, lamb, bacon and sausage are meatRaw. meatDeli is only sliced deli meat. Fruit that isn't berries is fruitWhole. Bread, pasta and snacks are other. Waffles, soups and ready meals are preparedMeals.")
    var category: FoodCategory

    @Guide(description: "Number of units purchased", .range(1...24))
    var quantity: Int

    @Guide(description: "True if this item is normally kept in a refrigerator")
    var needsRefrigeration: Bool
}
