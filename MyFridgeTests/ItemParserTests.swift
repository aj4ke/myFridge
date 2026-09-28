import Foundation
import FoundationModels
import Testing
@testable import MyFridge

struct ItemParserTests {
    let lines = (1...95).map { "Line \($0)" }

    /** Stand-in for the model: one item per line. */
    func items(for range: Range<Int>) -> [ParsedItem] {
        range.map { ParsedItem(line: $0 + 1, name: lines[$0], category: .other, quantity: 1, needsRefrigeration: true) }
    }

    @Test func fallbackTurnsEachLineIntoAnItem() async throws {
        let result = try await FallbackParser().parse(
            lines: ["ORG KALE 2.99 F", "Organic Red Onion | Qty: 0.88 lb @ $2.99/lb"],
            source: .screenshot
        )
        #expect(result.items.map(\.name) == ["ORG KALE 2.99 F", "Organic Red Onion"])
        #expect(result.items.map(\.line) == [1, 2])
        #expect(result.items.allSatisfy { $0.category == .other && $0.quantity == 1 && $0.needsRefrigeration })
    }

    @Test func promptNumbersLinesAcrossTheWholeImport() {
        let prompt = FoundationModelsParser.prompt(for: 40..<42, of: lines, source: .receipt)
        #expect(prompt.hasPrefix("Source: a paper grocery receipt."))
        #expect(prompt.hasSuffix("[41] Line 41\n[42] Line 42"))
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

    @Test func splitsChunksThatOverflowTheContextWindow() async throws {
        var requests: [Range<Int>] = []
        let result = try await FoundationModelsParser.parse(lines: lines) { range in
            requests.append(range)
            if range.count > 10 {
                throw LanguageModelSession.GenerationError.exceededContextWindowSize(.init(debugDescription: "too long"))
            }
            return items(for: range)
        }
        #expect(result.items.map(\.line) == Array(1...95))
        #expect(result.skippedLines.isEmpty)
        #expect(requests.filter { $0.count <= 10 }.map(\.count).reduce(0, +) == 95)
    }

    @Test func skipsAndReportsChunksTheModelDeclines() async throws {
        let result = try await FoundationModelsParser.parse(lines: lines) { range in
            if range.contains(45) {
                throw LanguageModelSession.GenerationError.guardrailViolation(.init(debugDescription: "declined"))
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
        ("Clover Sonoma Whole Milk", "Clover Sonoma Whole Milk, Half Gallon", .dairyMilk),
    ])
    func picksOutUltraPasteurizedMilk(name: String, line: String, expected: FoodCategory) {
        let item = ParsedItem(line: 1, name: name, category: .dairyMilk, quantity: 1, needsRefrigeration: true)
        #expect(FoundationModelsParser.refined(item, line: line).category == expected)
    }

    @Test func leavesOtherOrganicFoodAlone() {
        let onion = ParsedItem(line: 1, name: "Organic Red Onion", category: .produceOther, quantity: 1, needsRefrigeration: true)
        #expect(FoundationModelsParser.refined(onion, line: "Organic Red Onion").category == .produceOther)
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

        #expect(items.count >= 7)
        #expect(items.allSatisfy { lines.indices.contains($0.line - 1) })
        let salmon = try #require(items.first { $0.line == 2 })
        #expect(salmon.category == .seafoodRaw)
        #expect(salmon.needsRefrigeration)
        #expect(WeightExtractor.weight(in: lines[salmon.line - 1])?.pounds == 1.11)
        #expect(items.first { $0.line == 5 }?.category == .dairyMilkUltra)
    }
}

private nonisolated let isSimulator: Bool = {
    #if targetEnvironment(simulator)
    true
    #else
    false
    #endif
}()
