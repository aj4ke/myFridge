import Foundation
import SwiftData
import Testing
@testable import MyFridge

struct FridgeItemStoreTests {
    @Test func importSavesAllDraftsInOneSave() async throws {
        let container = try ModelContainer(for: FridgeItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let drafts = [
            DraftItem(name: "Organic Whole Milk", category: .dairyMilk, source: .screenshot),
            DraftItem(name: "Atlantic Salmon", category: .seafoodRaw, weight: (pounds: 1.11, unit: .pounds), source: .screenshot),
        ]

        try await FridgeItemStore.addImported(drafts, to: context)

        #expect(!context.hasChanges)
        let items = try context.fetch(FetchDescriptor<FridgeItem>(sortBy: [SortDescriptor(\.name)]))
        #expect(items.map(\.name) == ["Atlantic Salmon", "Organic Whole Milk"])
        #expect(items.first?.weightPounds == 1.11)
        #expect(items.allSatisfy { $0.source == .screenshot })
    }

    /** 2020 dates so no notifications get scheduled. */
    @Test func importRemembersOnlyHandSetExpiry() async throws {
        let container = try ModelContainer(for: FridgeItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let added = Calendar.current.date(from: DateComponents(year: 2020, month: 3, day: 1))!
        try await withTemporaryMemory { memory in
            let calculator = ExpiryCalculator(memory: memory)
            var milk = DraftItem(name: "Organic Milk", category: .dairyMilk, addedDate: added, calculator: calculator)
            milk.expiryDate = Calendar.current.date(byAdding: .day, value: 51, to: added)!
            milk.expiryEdited = true
            let eggs = DraftItem(name: "Eggs", category: .eggs, addedDate: added, calculator: calculator)

            try await FridgeItemStore.addImported([milk, eggs], to: container.mainContext, calculator: calculator)

            #expect(memory.days(for: "Organic Milk") == 51)
            #expect(memory.days(for: "Eggs") == nil)
        }
    }

    /** 2020 dates so no notifications get scheduled. */
    @Test func updateRemembersOnlyChangedExpiry() async {
        let added = Calendar.current.date(from: DateComponents(year: 2020, month: 3, day: 1))!
        let expiry = Calendar.current.date(byAdding: .day, value: 20, to: added)!
        await withTemporaryMemory { memory in
            let calculator = ExpiryCalculator(memory: memory)
            let item = FridgeItem(name: "Kale", category: .produceLeafy, addedDate: added, expiryDate: expiry)

            var sameExpiry = DraftItem(item, calculator: calculator)
            sameExpiry.quantity = 2
            FridgeItemStore.update(item, with: sameExpiry, calculator: calculator)
            #expect(memory.days(for: "Kale") == nil)

            var newExpiry = DraftItem(item, calculator: calculator)
            newExpiry.expiryDate = Calendar.current.date(byAdding: .day, value: 10, to: added)!
            newExpiry.expiryEdited = true
            FridgeItemStore.update(item, with: newExpiry, calculator: calculator)
            #expect(memory.days(for: "Kale") == 10)
        }
    }
}
