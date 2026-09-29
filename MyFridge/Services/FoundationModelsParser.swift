import Foundation
import FoundationModels

/** Sends 40 lines per request since the model's context is only about 4,096 tokens. */
nonisolated struct FoundationModelsParser: ItemParser {
    static let chunkSize = 40

    static let instructions = """
        You convert grocery receipt lines into a list of products. Whole Foods receipts use abbreviations such as \
        ORG (organic), 365 (store brand), SPNCH (spinach), BNLS (boneless), SKNLS (skinless), CHKN (chicken). \
        Expand abbreviations into normal product names. Ignore anything that isn't a product. Pick the closest category.
        Each input line starts with a number in square brackets; copy it into line. Keep brand names spelled as written. \
        A line may end with " | " and a quantity: "Qty: 2" or "2 @ 1.29" means quantity 2, and a weight such as \
        "0.88 lb" means quantity 1.
        Storage is where the product is kept at home before it's opened:
        freezer for food sold frozen, such as waffles, frozen pizza, ice cream and frozen vegetables.
        pantry for shelf-stable food, such as bread, buns, tortillas, pasta, rice, canned or boxed soup, \
        canned peppers such as chipotles, jarred sauce, chips and cereal.
        fridge for fresh meat, fish, milk, cheese, butter, eggs, cut fruit and ready-to-eat meals.
        notFood for household goods such as paper towels, soap and trash bags.
        """

    enum ParserError: LocalizedError {
        case unavailable(SystemLanguageModel.Availability.UnavailableReason)

        var errorDescription: String? {
            switch self {
            case .unavailable(.deviceNotEligible): "This iPhone doesn't support Apple Intelligence."
            case .unavailable(.appleIntelligenceNotEnabled): "Apple Intelligence is turned off in Settings."
            case .unavailable(.modelNotReady): "The Apple Intelligence model is still downloading."
            case .unavailable: "Apple Intelligence isn't available."
            }
        }
    }

    /** New session per chunk plus greedy sampling, so the same lines always parse the same way. */
    func parse(lines: [String], source: ItemSource) async throws -> ParseResult {
        if case .unavailable(let reason) = SystemLanguageModel.default.availability {
            throw ParserError.unavailable(reason)
        }
        var result = try await Self.parse(lines: lines) { range in
            let session = LanguageModelSession(instructions: Self.instructions)
            let response = try await session.respond(
                to: Self.prompt(for: range, of: lines, source: source),
                generating: ParsedReceipt.self,
                options: GenerationOptions(samplingMode: .greedy)
            )
            return response.content.items
        }
        result.items = result.items.map { item in
            Self.refined(item, line: lines.indices.contains(item.line - 1) ? lines[item.line - 1] : "")
        }
        return result
    }

    /**
     * The model files all milk under Milk. Organic, UHT, ultra and lactose-free usually mean ultra-pasteurized.
     * It also files waffles as bread, so words for food that's sold frozen send it to the freezer.
     */
    static func refined(_ item: ParsedItem, line: String) -> ParsedItem {
        var item = item
        let text = item.name + " " + line
        let longLifePattern = #"\b(ORG|ORGANIC|ULTRA|UHT|LACTOSE[- ]?FREE|LACTAID|FAIRLIFE)\b"#
        if item.category == .dairyMilk, text.range(of: longLifePattern, options: [.regularExpression, .caseInsensitive]) != nil {
            item.category = .dairyMilkUltra
        }
        let frozenPattern = #"\b(FROZEN|WAFFLES?(?!\s+(MIX|CONES?))|ICE CREAM|POPSICLES?|SORBET|GELATO)\b"#
        if item.storage != .notFood, text.range(of: frozenPattern, options: [.regularExpression, .caseInsensitive]) != nil {
            item.storage = .freezer
        }
        return item
    }

    /** Too-long chunks are split in half and retried. Chunks the model refuses are skipped and reported. */
    static func parse(
        lines: [String],
        respond: (Range<Int>) async throws -> [ParsedItem]
    ) async throws -> ParseResult {
        var result = ParseResult(items: [])
        for start in stride(from: 0, to: lines.count, by: chunkSize) {
            try await parse(start..<min(start + chunkSize, lines.count), of: lines, into: &result, respond: respond)
        }
        return result
    }

    private static func parse(
        _ range: Range<Int>,
        of lines: [String],
        into result: inout ParseResult,
        respond: (Range<Int>) async throws -> [ParsedItem]
    ) async throws {
        do {
            result.items += try await respond(range)
        } catch let error where isContextOverflow(error) && range.count > 1 {
            let middle = range.lowerBound + range.count / 2
            try await parse(range.lowerBound..<middle, of: lines, into: &result, respond: respond)
            try await parse(middle..<range.upperBound, of: lines, into: &result, respond: respond)
        } catch let error where isContextOverflow(error) || wasDeclined(error) {
            result.skippedLines += lines[range]
        }
    }

    /** Line numbers count across the whole import so ParsedItem.line indexes into all lines. */
    static func prompt(for range: Range<Int>, of lines: [String], source: ItemSource) -> String {
        let hint = switch source {
        case .receipt: "Source: a paper grocery receipt. Item names are abbreviated."
        case .screenshot: #"Source: text from an Amazon order page screenshot. Product names are complete; quantities look like "Qty: 2"."#
        case .manual: ""
        }
        let numbered = range.map { "[\($0 + 1)] \(lines[$0])" }.joined(separator: "\n")
        return hint + "\n\n" + numbered
    }

    /** iOS 26 and 27 throw different error types for this. */
    private static func isContextOverflow(_ error: any Error) -> Bool {
        if case LanguageModelSession.GenerationError.exceededContextWindowSize = error { return true }
        if #available(iOS 27.0, *), case LanguageModelError.contextSizeExceeded = error { return true }
        return false
    }

    /** iOS 26 and 27 throw different error types for this. */
    private static func wasDeclined(_ error: any Error) -> Bool {
        switch error {
        case LanguageModelSession.GenerationError.guardrailViolation, LanguageModelSession.GenerationError.refusal:
            return true
        default:
            break
        }
        if #available(iOS 27.0, *) {
            switch error {
            case LanguageModelError.guardrailViolation, LanguageModelError.refusal:
                return true
            default:
                break
            }
        }
        return false
    }
}
