import Foundation
import FoundationModels
import Testing
@testable import MyFridge

struct ItemParserTests {
    let lines = (1...95).map { "Line \($0)" }

    /** Stand-in for the model: one item per line. */
    func items(for range: Range<Int>) -> [ParsedItem] {
        range.map { ParsedItem(line: $0 + 1, name: lines[$0], storage: .fridge, category: .other, quantity: 1) }
    }

    @Test func fallbackTurnsEachLineIntoAnItem() async throws {
        let result = try await FallbackParser().parse(
            lines: ["ORG KALE 2.99 F", "Organic Red Onion | Qty: 0.88 lb @ $2.99/lb"],
            source: .screenshot
        )
        #expect(result.items.map(\.name) == ["ORG KALE 2.99 F", "Organic Red Onion"])
        #expect(result.items.map(\.line) == [1, 2])
        #expect(result.items.allSatisfy { $0.category == .other && $0.quantity == 1 && $0.storage == .fridge })
    }

    @Test func promptNumbersLinesAcrossTheWholeImport() {
        let prompt = FoundationModelsParser.prompt(for: 40..<42, of: lines, source: .receipt)
        #expect(prompt.hasSuffix("[41] Line 41\n[42] Line 42"))
    }

    @Test(arguments: [
        (ItemSource.receipt, "Source: a paper grocery receipt."),
        (.screenshot, "Source: text from an Amazon order page screenshot."),
        (.manual, "\n\n[1] Line 1"),
    ])
    func promptStartsWithSourceHint(source: ItemSource, prefix: String) {
        #expect(FoundationModelsParser.prompt(for: 0..<1, of: lines, source: source).hasPrefix(prefix))
    }

    @Test func emptyImportSendsNoRequests() async throws {
        var requests = 0
        let result = try await FoundationModelsParser.parse(lines: []) { _ in
            requests += 1
            return []
        }
        #expect(requests == 0)
        #expect(result.items.isEmpty)
    }

    @Test func sendsFortyLinesPerRequest() async throws {
        var requests: [Range<Int>] = []
        let result = try await FoundationModelsParser.parse(lines: lines) { range in
            requests.append(range)
            return items(for: range)
        }
        #expect(requests == [0..<40, 40..<80, 80..<95])
        #expect(result.items.map(\.line) == Array(1...95))
    }

    @Test(arguments: overflowErrors)
    func splitsChunksThatOverflowTheContextWindow(_ overflow: any Error) async throws {
        var requests: [Range<Int>] = []
        let result = try await FoundationModelsParser.parse(lines: lines) { range in
            requests.append(range)
            if range.count > 10 {
                throw overflow
            }
            return items(for: range)
        }
        #expect(result.items.map(\.line) == Array(1...95))
        #expect(result.skippedLines.isEmpty)
        #expect(requests.filter { $0.count <= 10 }.map(\.count).reduce(0, +) == 95)
    }

    @Test(arguments: overflowErrors)
    func skipsALineThatOverflowsOnItsOwn(_ overflow: any Error) async throws {
        let result = try await FoundationModelsParser.parse(lines: lines) { range in
            if range.contains(50) {
                throw overflow
            }
            return items(for: range)
        }
        #expect(result.skippedLines == ["Line 51"])
        #expect(result.items.map(\.line) == Array(1...50) + Array(52...95))
    }

    @Test(arguments: declinedErrors)
    func skipsAndReportsChunksTheModelDeclines(_ declined: any Error) async throws {
        let result = try await FoundationModelsParser.parse(lines: lines) { range in
            if range.contains(45) {
                throw declined
            }
            return items(for: range)
        }
        #expect(result.skippedLines == Array(lines[40..<80]))
        #expect(result.items.map(\.line) == Array(1...40) + Array(81...95))
    }

    @Test func otherErrorsFailTheImport() async {
        struct Offline: Error {}
        await #expect(throws: Offline.self) {
            try await FoundationModelsParser.parse(lines: lines) { _ in throw Offline() }
        }
    }

    @Test(arguments: [
        ("Organic Whole Milk", "365 by Whole Foods Market, Organic Whole Milk, 64 oz | Qty: 1@$4.39 each", FoodCategory.dairyMilkUltra),
        ("Whole Milk", "365 ORG WHL MILK 4.39 F", .dairyMilkUltra),
        ("Half & Half", "Organic Valley Ultra Pasteurized Half & Half, 1 pint", .dairyMilkUltra),
        ("Lactose Free Whole Milk", "Lactaid Lactose Free Whole Milk, 96 oz", .dairyMilkUltra),
        ("Fairlife 2% Milk", "Fairlife 2% Reduced Fat Milk, 52 fl oz", .dairyMilkUltra),
        ("Clover Sonoma Whole Milk", "Clover Sonoma Whole Milk, Half Gallon", .dairyMilk),
        ("Whole Milk", "GEORGIA DAIRY WHOLE MILK", .dairyMilk),
    ])
    func picksOutUltraPasteurizedMilk(name: String, line: String, expected: FoodCategory) {
        let item = ParsedItem(line: 1, name: name, storage: .fridge, category: .dairyMilk, quantity: 1)
        #expect(FoundationModelsParser.refined(item, line: line).category == expected)
    }

    @Test func leavesOtherOrganicFoodAlone() {
        let onion = ParsedItem(line: 1, name: "Organic Red Onion", storage: .fridge, category: .produceOther, quantity: 1)
        #expect(FoundationModelsParser.refined(onion, line: "Organic Red Onion").category == .produceOther)
    }

    @Test(arguments: [
        ("Protein Waffles", "365 By Whole Foods Market, Protein Waffles, Buttermilk, 6 Count", ParsedStorage.freezer),
        ("Blueberries", "Frozen Organic Blueberries, 32 oz", .freezer),
        ("Vanilla Ice Cream", "Talenti Vanilla Ice Cream, 1 pint", .freezer),
        ("Waffle Mix", "Birch Benders Waffle Mix, 16 oz", .pantry),
        ("Waffle Cones", "Joy Waffle Cones, 12 ct", .pantry),
        ("Sourdough Bread", "Sourdough Half Deli Loaf, 21 oz", .pantry),
    ])
    func sendsFoodSoldFrozenToTheFreezer(name: String, line: String, expected: ParsedStorage) {
        let item = ParsedItem(line: 1, name: name, storage: .pantry, category: .breadBakery, quantity: 1)
        #expect(FoundationModelsParser.refined(item, line: line).storage == expected)
    }

    @Test func frozenWordsDontMakeHouseholdGoodsFood() {
        let bags = ParsedItem(line: 1, name: "Freezer Bags", storage: .notFood, category: .other, quantity: 1)
        #expect(FoundationModelsParser.refined(bags, line: "Ziploc Frozen Food Freezer Bags").storage == .notFood)
    }

    @Test func eachUnavailableReasonHasItsOwnMessage() {
        let reasons: [SystemLanguageModel.Availability.UnavailableReason] = [.deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady]
        let messages = reasons.compactMap { FoundationModelsParser.ParserError.unavailable($0).errorDescription }
        #expect(Set(messages).count == reasons.count)
    }

    @Test(
        .enabled(if: SystemLanguageModel.default.isAvailable),
        .disabled(if: isSimulator, "The simulator reports the model as available but has no model assets"),
        .timeLimit(.minutes(1))
    )
    func onDeviceModelParsesAmazonOrder() async throws {
        let lines = [
            "Organic Red Onion | Qty: 0.88 b @$2.99/1b",
            "Center Cut Atlantic Salmon Portion | Qty: 1.11 lb @ $18.99/1b",
            "365 By Whole Foods Market, Protein Waffles, Buttermilk, 6 Count, 8 Ounce | Qty: 1@$3.79 each",
            "Nashoba Brook Bakery Sourdough Half Deli Loaf, 21 oz | Qty: 1 @ $6.99 each",
            "365 by Whole Foods Market, Organic Whole Milk, 64 oz | Qty: 1@$4.39 each",
            "Andrew & Everett, Cheeese Sliced Thin American White, 7 Ounce | Qty: 1 @ $5.29 each",
            "Pineapple Chunks Small | Qty: 0.69 lb @$5.49/lb",
            "365 by Whole Foods Market, Organic Chicken Noodle Soup, 18.6 Ounce",
        ]
        let items = try await FoundationModelsParser().parse(lines: lines, source: .screenshot).items
        print(items.map { "MODEL-OUTPUT \($0.line) | \($0.name) | \($0.category) | \($0.storage)" }.joined(separator: "\n"))

        #expect(items.count >= 7)
        #expect(items.allSatisfy { lines.indices.contains($0.line - 1) })
        let salmon = try #require(items.first { $0.line == 2 })
        #expect(salmon.category == .seafoodRaw)
        #expect(salmon.storage == .fridge)
        #expect(WeightExtractor.weight(in: lines[salmon.line - 1])?.pounds == 1.11)
        #expect(items.first { $0.line == 5 }?.category == .dairyMilkUltra)

        let modes = StorageModes(pantry: true, freezer: true)
        func placement(line: Int) throws -> StorageLocation {
            try ImportService.placement(for: #require(items.first { $0.line == line }), modes: modes).location
        }
        #expect(try placement(line: 2) == .fridge)
        #expect(try placement(line: 3) == .freezer, "Protein waffles are sold frozen")
        #expect(try placement(line: 4) == .pantry, "Sourdough loaf")
        #expect(items.first { $0.line == 4 }?.category == .breadBakery)
        #expect(try placement(line: 5) == .fridge)
        #expect(try placement(line: 6) == .fridge, "Sliced cheese")
        #expect(try placement(line: 7) == .fridge, "Cut fruit")
        #expect(try placement(line: 8) == .pantry, "Shelf-stable soup")
    }
}

/** iOS 26 and 27 throw different error types, so the chunking tests run with each. */
private nonisolated let overflowErrors: [any Error] = {
    var errors: [any Error] = [LanguageModelSession.GenerationError.exceededContextWindowSize(.init(debugDescription: "too long"))]
    if #available(iOS 27.0, *) {
        errors.append(LanguageModelError.contextSizeExceeded(.init(contextSize: 4096, tokenCount: 5000, debugDescription: "too long")))
    }
    return errors
}()

private nonisolated let declinedErrors: [any Error] = {
    var errors: [any Error] = [
        LanguageModelSession.GenerationError.guardrailViolation(.init(debugDescription: "declined")),
        LanguageModelSession.GenerationError.refusal(.init(transcriptEntries: []), .init(debugDescription: "declined")),
    ]
    if #available(iOS 27.0, *) {
        errors += [
            LanguageModelError.guardrailViolation(.init(debugDescription: "declined")),
            LanguageModelError.refusal(.init(explanation: "declined", debugDescription: "declined")),
        ]
    }
    return errors
}()
