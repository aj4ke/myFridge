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

    @Test func keepsEachNameSeparately() async {
        await withTemporaryMemory { memory in
            memory.remember(50, for: "Milk")
            memory.remember(9, for: "Jalapeño Peppers")
            #expect(memory.days(for: "Milk") == 50)
            #expect(memory.days(for: "JALAPENO PEPPERS") == 9)
        }
    }
}
