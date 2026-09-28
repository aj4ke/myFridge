import Foundation
import SwiftData
import Testing
@testable import MyFridge

/** 2020 dates so no notifications get scheduled. */
struct FridgeItemStoreTests {
    let added = date(2020, 3, 1)

    func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(for: FridgeItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func days(_ count: Int) -> Date {
        testCalendar.date(byAdding: .day, value: count, to: added)!
    }

    @Test func importSavesAllDraftsInOneSave() async throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let calculator = ExpiryCalculator.testing()
        let drafts = [
            DraftItem(name: "Organic Whole Milk", category: .dairyMilk, addedDate: added, source: .screenshot, calculator: calculator),
            DraftItem(
                name: "Atlantic Salmon",
                category: .seafoodRaw,
                weight: (pounds: 1.11, unit: .pounds),
                addedDate: added,
                source: .screenshot,
                calculator: calculator
            ),
        ]

        try await FridgeItemStore.addImported(drafts, to: context, calculator: calculator)

        #expect(!context.hasChanges)
        let items = try context.fetch(FetchDescriptor<FridgeItem>(sortBy: [SortDescriptor(\.name)]))
        #expect(items.map(\.name) == ["Atlantic Salmon", "Organic Whole Milk"])
        #expect(items.first?.weightPounds == 1.11)
        #expect(items.allSatisfy { $0.source == .screenshot })
    }

    @Test func importRemembersOnlyHandSetExpiry() async throws {
        let container = try inMemoryContainer()
        try await withTemporaryMemory { memory in
            let calculator = ExpiryCalculator.testing(memory: memory)
            var milk = DraftItem(name: "Organic Milk", category: .dairyMilk, addedDate: added, calculator: calculator)
            milk.expiryDate = days(51)
            milk.expiryEdited = true
            let eggs = DraftItem(name: "Eggs", category: .eggs, addedDate: added, calculator: calculator)

            try await FridgeItemStore.addImported([milk, eggs], to: container.mainContext, calculator: calculator)

            #expect(memory.days(for: "Organic Milk") == 51)
            #expect(memory.days(for: "Eggs") == nil)
        }
    }

    /**
     * add() reads the item again in a notification Task. Reading it after the container is freed crashes the
     * whole test run, so the Task gets to run first and the container is used after it.
     */
    @Test func addInsertsItemAndRemembersOnlyHandSetExpiry() async throws {
        let container = try inMemoryContainer()
        try await withTemporaryMemory { memory in
            let calculator = ExpiryCalculator.testing(memory: memory)
            var kale = DraftItem(name: "Kale", category: .produceLeafy, addedDate: added, calculator: calculator)
            kale.expiryDate = days(9)
            kale.expiryEdited = true
            let eggs = DraftItem(name: "Eggs", category: .eggs, addedDate: added, calculator: calculator)

            FridgeItemStore.add(kale, to: container.mainContext, calculator: calculator)
            FridgeItemStore.add(eggs, to: container.mainContext, calculator: calculator)
            await Task.yield()

            let items = try container.mainContext.fetch(FetchDescriptor<FridgeItem>(sortBy: [SortDescriptor(\.name)]))
            #expect(items.map(\.name) == ["Eggs", "Kale"])
            #expect(items.last?.expiryDate == days(9))
            #expect(memory.days(for: "Kale") == 9)
            #expect(memory.days(for: "Eggs") == nil)
        }
    }

    @Test func updateRemembersOnlyChangedExpiry() async {
        await withTemporaryMemory { memory in
            let calculator = ExpiryCalculator.testing(memory: memory)
            let item = FridgeItem(name: "Kale", category: .produceLeafy, addedDate: added, expiryDate: days(20))

            var sameExpiry = DraftItem(item, calculator: calculator)
            sameExpiry.quantity = 2
            FridgeItemStore.update(item, with: sameExpiry, calculator: calculator)
            #expect(item.quantity == 2)
            #expect(memory.days(for: "Kale") == nil)

            var newExpiry = DraftItem(item, calculator: calculator)
            newExpiry.expiryDate = days(10)
            newExpiry.expiryEdited = true
            FridgeItemStore.update(item, with: newExpiry, calculator: calculator)
            #expect(item.expiryDate == days(10))
            #expect(memory.days(for: "Kale") == 10)
        }
    }
}
