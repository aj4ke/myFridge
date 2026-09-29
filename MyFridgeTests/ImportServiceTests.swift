import Foundation
import Testing
@testable import MyFridge

struct ImportServiceTests {
    let lines = [
        "Organic Red Onion | Qty: 0.88 b @$2.99/1b",
        "Organic Whole Milk, 64 oz | Qty: 1 @ $4.39 each",
        "BNLS SKNLS CHKN BRST 8.47 F | 1.52 lb @ 5.57 /lb",
        "Sliced Turkey | Qty: 12 oz @ $0.50/oz",
    ]

    func item(
        line: Int,
        _ name: String = "Item",
        category: FoodCategory = .other,
        quantity: Int = 1,
        storage: ParsedStorage = .fridge
    ) -> ParsedItem {
        ParsedItem(line: line, name: name, storage: storage, category: category, quantity: quantity)
    }

    /** The model doesn't return items in line order, so each weight has to come from the item's own line. */
    @Test func weightComesFromTheItemsOwnLine() {
        let weights = [4, 1, 3, 2].map { ImportService.weight(for: item(line: $0), in: lines) }
        #expect(weights.map { $0?.pounds } == [0.75, 0.88, 1.52, nil])
        #expect(weights.map { $0?.unit } == [.ounces, .pounds, .pounds, nil])
    }

    /** Line numbers come from the model, so they can point outside the import. */
    @Test(arguments: [0, -1, 5, 99])
    func lineOutsideTheImportHasNoWeight(_ line: Int) {
        #expect(ImportService.weight(for: item(line: line), in: lines) == nil)
    }

    @Test func draftsKeepParsedFieldsAndPurchaseDate() {
        let items = [
            item(line: 1, "Organic Red Onion", category: .produceOther),
            item(line: 2, "Organic Whole Milk", category: .dairyMilkUltra, quantity: 2),
            item(line: 5, "Paper Towels", storage: .notFood),
        ]
        let drafts = ImportService.drafts(
            from: items, lines: lines, source: .screenshot, addedOn: date(2026, 9, 28), modes: StorageModes(), calculator: .testing()
        )

        #expect(drafts.map(\.name) == ["Organic Red Onion", "Organic Whole Milk", "Paper Towels"])
        #expect(drafts.map(\.category) == [.produceOther, .dairyMilkUltra, .other])
        #expect(drafts.map(\.quantity) == [1, 2, 1])
        #expect(drafts.map(\.weightPounds) == [0.88, nil, nil])
        #expect(drafts.map(\.isIncluded) == [true, true, false])
        #expect(drafts.map(\.skipReason) == [nil, nil, .notFood])
        #expect(drafts.allSatisfy { $0.source == .screenshot && $0.addedDate == date(2026, 9, 28) && !$0.expiryEdited })
        /* Onions keep 60 days in food_shelf_life.json. */
        #expect(drafts[0].expiryDate == date(2026, 11, 27))
    }

    @Test(arguments: [
        (ParsedStorage.fridge, FoodCategory.dairyMilk, StorageModes(), StorageLocation.fridge, DraftItem.SkipReason?.none),
        (.pantry, .breadBakery, StorageModes(pantry: true), .pantry, nil),
        (.pantry, .breadBakery, StorageModes(), .fridge, .locationOff(.pantry)),
        (.freezer, .poultryRaw, StorageModes(freezer: true), .freezer, nil),
        (.freezer, .poultryRaw, StorageModes(), .fridge, .locationOff(.freezer)),
        (.fridge, .frozenMeals, StorageModes(freezer: true), .freezer, nil),
        (.pantry, .meatRaw, StorageModes(pantry: true), .fridge, nil),
        (.notFood, .other, StorageModes(pantry: true, freezer: true), .fridge, .notFood),
    ])
    func placesEachItem(
        storage: ParsedStorage,
        category: FoodCategory,
        modes: StorageModes,
        location: StorageLocation,
        skipReason: DraftItem.SkipReason?
    ) {
        let placement = ImportService.placement(for: item(line: 1, category: category, storage: storage), modes: modes)
        #expect(placement.location == location)
        #expect(placement.skipReason == skipReason)
    }

    @Test(arguments: [
        ("Organic Red Onion", FoodCategory.produceOther, StorageLocation.pantry),
        ("Bananas", .fruitWhole, .pantry),
        ("Pineapple Chunks", .fruitWhole, .fridge),
        ("Baby Spinach Salad Mix", .produceOther, .fridge),
    ])
    func produceOnlyGoesToThePantryWhenItKeepsThere(_ name: String, category: FoodCategory, location: StorageLocation) {
        let placement = ImportService.placement(for: item(line: 1, name, category: category, storage: .pantry), modes: StorageModes(pantry: true))
        #expect(placement.location == location)
    }

    @Test func frozenImportsCountFromPurchase() {
        let waffles = item(line: 2, "Frozen Waffles", category: .frozenMeals, storage: .freezer)
        let drafts = ImportService.drafts(
            from: [waffles], lines: lines, source: .receipt, addedOn: date(2026, 9, 28), modes: StorageModes(freezer: true), calculator: .testing()
        )
        #expect(drafts.first?.location == .freezer)
        #expect(drafts.first?.frozenDate == date(2026, 9, 28))
        #expect(drafts.first?.isIncluded == true)
        #expect(drafts.first?.expiryDate == date(2026, 12, 27))
    }

    @Test func noImportMakesNoDrafts() {
        #expect(ImportService().makeDrafts(addedOn: date(2026, 9, 28)).isEmpty)
    }
}
