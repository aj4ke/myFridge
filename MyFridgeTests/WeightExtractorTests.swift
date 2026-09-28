import Testing
@testable import MyFridge

struct WeightExtractorTests {
    @Test(arguments: [
        ("Organic Red Onion | Qty: 0.88 b @$2.99/1b", 0.88, WeightUnit.pounds),
        ("Center Cut Atlantic Salmon Portion | Qty: 1.11 lb @ $18.99/1b", 1.11, .pounds),
        ("Pineapple Chunks Small | Qty: 0.69 lb @$5.49/lb", 0.69, .pounds),
        ("Qty: 2.5 lbs @ $3.99/lb", 2.5, .pounds),
        ("Qty: 1.2 Ib @ $4.99/lb", 1.2, .pounds),
        ("Qty: 0.75 1b @ $6.99/lb", 0.75, .pounds),
        ("BNLS SKNLS CHKN BRST 8.47 F | 1.52 lb @ 5.57 /lb", 1.52, .pounds),
        ("Qty: 12 oz @ $0.50/oz", 0.75, .ounces),
    ])
    func findsWeight(_ line: String, pounds: Double, unit: WeightUnit) throws {
        let weight = try #require(WeightExtractor.weight(in: line))
        #expect(weight.pounds == pounds)
        #expect(weight.unit == unit)
    }

    @Test(arguments: [
        "365 by Whole Foods Market, Organic Whole Milk, 64 oz | Qty: 1@$4.39 each",
        "365 By Whole Foods Market, Protein Waffles, Buttermilk, 6 Count, 8 Ounce | Qty: 1@$3.79 each",
        "365 by Whole Foods Market, Organic Chicken Noodle Soup, 18.6 Ounce",
        "Checkout Bag Charge | Qty: 2@$0.10 each",
        "ORG STRAWBERRIES 4.99 F",
        "2 @ 1.29",
    ])
    func ignoresLinesWithoutWeight(_ line: String) {
        #expect(WeightExtractor.weight(in: line) == nil)
    }
}
