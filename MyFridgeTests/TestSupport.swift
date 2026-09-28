import Foundation
@testable import MyFridge

/** A fixed zone with daylight saving, so date tests don't depend on where they run. */
nonisolated let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    return calendar
}()

nonisolated func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
    testCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

nonisolated extension ShelfLifeMemory {
    /** Never written to, so it always reads as empty. */
    static let empty = ShelfLifeMemory(suiteName: "MyFridgeTests.empty")
}

nonisolated extension ExpiryCalculator {
    /** The default ExpiryCalculator() reads what the simulator app has learned, so tests use this instead. */
    static func testing(
        shelfLife: ShelfLifeService = .shared,
        foods: FoodShelfLife = .shared,
        memory: ShelfLifeMemory = .empty
    ) -> ExpiryCalculator {
        ExpiryCalculator(shelfLife: shelfLife, foods: foods, memory: memory, calendar: testCalendar)
    }
}

/** Uses a throwaway UserDefaults suite so tests don't touch the app's saved values. */
func withTemporaryMemory(_ body: (ShelfLifeMemory) async throws -> Void) async rethrows {
    let suiteName = "MyFridgeTests.\(UUID().uuidString)"
    defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
    try await body(ShelfLifeMemory(suiteName: suiteName))
}
