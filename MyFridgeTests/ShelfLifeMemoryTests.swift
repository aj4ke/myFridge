import Foundation
import Testing
@testable import MyFridge

/** Uses a throwaway UserDefaults suite so tests don't touch the app's saved values. */
func withTemporaryMemory(_ body: (ShelfLifeMemory) async throws -> Void) async rethrows {
    let suiteName = "MyFridgeTests.\(UUID().uuidString)"
    defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
    try await body(ShelfLifeMemory(suiteName: suiteName))
}

struct ShelfLifeMemoryTests {
    @Test func remembersByCleanedUpName() async {
        await withTemporaryMemory { memory in
            memory.remember(50, for: "Organic Whole Milk")
            #expect(memory.days(for: "organic  whole milk!") == 50)
            #expect(memory.days(for: "Whole Milk") == nil)
        }
    }

    @Test func newValueReplacesOld() async {
        await withTemporaryMemory { memory in
            memory.remember(50, for: "Milk")
            memory.remember(10, for: "Milk")
            #expect(memory.days(for: "Milk") == 10)
        }
    }
}
