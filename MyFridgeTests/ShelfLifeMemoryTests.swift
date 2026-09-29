import Foundation
import Testing
@testable import MyFridge

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

    @Test func keepsEachLocationSeparately() async {
        await withTemporaryMemory { memory in
            memory.remember(7, for: "Milk")
            memory.remember(90, for: "Milk", in: .freezer)
            #expect(memory.days(for: "Milk") == 7)
            #expect(memory.days(for: "Milk", in: .freezer) == 90)
            #expect(memory.days(for: "Milk", in: .pantry) == nil)
        }
    }

    /** Values learned before pantry and freezer existed are stored under this key. */
    @Test func fridgeKeepsTheOriginalKey() {
        #expect(ShelfLifeMemory.storageKey(for: .fridge) == "learnedShelfLife")
    }

    @Test func keepsEachNameSeparately() async {
        await withTemporaryMemory { memory in
            memory.remember(50, for: "Milk")
            memory.remember(9, for: "Jalapeño Peppers")
            #expect(memory.days(for: "Milk") == 50)
            #expect(memory.days(for: "JALAPENO PEPPERS") == 9)
        }
    }
}
