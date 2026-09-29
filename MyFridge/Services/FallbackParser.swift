import Foundation

nonisolated struct FallbackParser: ItemParser {
    /** The weight is still read later from the full line, including the " | Qty" part. */
    func parse(lines: [String], source: ItemSource) async throws -> ParseResult {
        ParseResult(items: lines.enumerated().map { index, line in
            ParsedItem(
                line: index + 1,
                name: line.components(separatedBy: " | ").first ?? line,
                storage: .fridge,
                category: .other,
                quantity: 1
            )
        })
    }
}
