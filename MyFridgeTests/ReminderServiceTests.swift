import EventKit
import Foundation
import Testing
@testable import MyFridge

/**
 * Runs against the simulator's real Reminders, each test in its own throwaway list.
 * scripts/test.sh grants Reminders access before the tests start.
 */
struct ReminderServiceTests {
    let milk = FridgeItem(name: "Whole Milk", category: .dairyMilk, expiryDate: date(2026, 10, 5))
    let bread = FridgeItem(name: "Sourdough", category: .breadBakery, expiryDate: date(2026, 10, 12, hour: 15), location: .pantry)

    @Test func dueDateIsNineOnTheExpiryDay() {
        #expect(ReminderService.dueDate(forExpiry: date(2026, 10, 5, hour: 18), calendar: testCalendar) == date(2026, 10, 5, hour: 9))
    }

    @Test(.remindersAccess) func syncMakesTheListWithOneReminderPerItem() async throws {
        try await withTestList { service, list in
            try await service.sync([milk, bread])

            let reminders = await list.reminders()
            #expect(reminders.map(\.title) == ["Sourdough", "Whole Milk"])
            #expect(reminders.map(\.notes) == ["Pantry", "Fridge"])
            #expect(reminders.map(\.due) == [date(2026, 10, 12, hour: 9), date(2026, 10, 5, hour: 9)])
            #expect(reminders.map(\.alarmDates) == [[date(2026, 10, 12, hour: 9)], [date(2026, 10, 5, hour: 9)]])
            #expect(reminders.allSatisfy { !$0.isCompleted })
        }
    }

    @Test(.remindersAccess) func syncUpdatesRemindersInPlace() async throws {
        try await withTestList { service, list in
            try await service.sync([milk, bread])
            let id = try #require(await list.reminders().last?.id)

            milk.name = "Organic Whole Milk"
            milk.expiryDate = date(2026, 10, 20)
            try await service.sync([milk, bread])

            let reminders = await list.reminders()
            #expect(reminders.count == 2)
            let updated = try #require(reminders.first { $0.id == id })
            #expect(updated.title == "Organic Whole Milk")
            #expect(updated.due == date(2026, 10, 20, hour: 9))
        }
    }

    /** Stands in for someone using the Reminders app, through a second store. */
    @Test(.remindersAccess) func syncUndoesChangesMadeInReminders() async throws {
        try await withTestList { service, list in
            try await service.sync([milk, bread])
            let store = EKEventStore()
            let reminders = await list.reminders(in: store)
            let milkReminder = try #require(reminders.last)
            milkReminder.isCompleted = true
            milkReminder.title = "Milk (done)"
            try store.save(milkReminder, commit: false)
            try store.remove(try #require(reminders.first), commit: false)
            let calendar = try #require(list.calendar(in: store))
            let stray = EKReminder(eventStore: store)
            stray.title = "Added by hand"
            stray.calendar = calendar
            try store.save(stray, commit: false)
            try store.commit()

            try await service.sync([milk, bread])

            let restored = await list.reminders()
            #expect(restored.map(\.title) == ["Sourdough", "Whole Milk"])
            #expect(restored.allSatisfy { !$0.isCompleted })
            #expect(restored.last?.id == milkReminder.calendarItemIdentifier)
        }
    }

    /** A relaunched app has a new store, and should leave reminders that already match alone. */
    @Test(.remindersAccess) func relaunchLeavesMatchingRemindersAlone() async throws {
        try await withTestList { service, list in
            try await service.sync([milk, bread])
            let before = await list.reminders()

            let relaunched = ReminderService(defaults: UserDefaults(suiteName: list.suiteName)!, listName: list.name, calendar: testCalendar)
            try await relaunched.sync([milk, bread])

            let after = await list.reminders()
            #expect(after.map(\.id) == before.map(\.id))
            #expect(after.map(\.modified) == before.map(\.modified))
        }
    }

    @Test(.remindersAccess) func syncRemovesRemindersForItemsThatAreGone() async throws {
        try await withTestList { service, list in
            try await service.sync([milk, bread])
            try await service.sync([milk])
            #expect(await list.reminders().map(\.title) == ["Whole Milk"])
        }
    }

    @Test(.remindersAccess) func saveAddsThenUpdatesOneReminder() async throws {
        try await withTestList { service, list in
            try service.save(milk)
            milk.expiryDate = date(2026, 10, 9)
            try service.save(milk)

            let reminders = await list.reminders()
            #expect(reminders.map(\.title) == ["Whole Milk"])
            #expect(reminders.first?.due == date(2026, 10, 9, hour: 9))
        }
    }

    @Test(.remindersAccess) func removeDeletesOnlyThatItemsReminder() async throws {
        try await withTestList { service, list in
            try await service.sync([milk, bread])
            try service.remove(bread)
            #expect(await list.reminders().map(\.title) == ["Whole Milk"])
        }
    }

    @Test(.remindersAccess) func deletedListIsMadeAgain() async throws {
        try await withTestList { service, list in
            try await service.sync([milk])
            let store = EKEventStore()
            try store.removeCalendar(try #require(list.calendar(in: store)), commit: true)

            try await service.sync([milk, bread])
            #expect(await list.reminders().map(\.title) == ["Sourdough", "Whole Milk"])
        }
    }

    @Test(.remindersAccess) func deleteListRemovesEverything() async throws {
        try await withTestList { service, list in
            try await service.sync([milk, bread])
            try await service.deleteList()
            #expect(list.calendar(in: EKEventStore()) == nil)
        }
    }

    /** A reinstall loses the saved list id, and should find the list by name instead of making a second one. */
    @Test(.remindersAccess) func reinstallReusesTheListWithTheSameName() async throws {
        try await withTestList { service, list in
            try await service.sync([milk, bread])
            let suiteName = "MyFridgeTests.\(UUID().uuidString)"
            defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
            let reinstalled = ReminderService(defaults: UserDefaults(suiteName: suiteName)!, listName: list.name, calendar: testCalendar)
            try await reinstalled.sync([milk])

            #expect(EKEventStore().calendars(for: .reminder).count { $0.title == list.name } == 1)
            #expect(await list.reminders().map(\.title) == ["Whole Milk"])
        }
    }
}

extension Trait where Self == ConditionTrait {
    static var remindersAccess: Self {
        .enabled(if: ReminderService.hasAccess, "Needs Reminders access: xcrun simctl privacy booted grant reminders com.ajake.MyFridge")
    }
}

/** Reads a test list the way the Reminders app would see it, through stores of its own. */
struct TestList {
    let name = "MyFridge Tests \(UUID().uuidString.prefix(8))"
    let suiteName = "MyFridgeTests.\(UUID().uuidString)"

    func calendar(in store: EKEventStore) -> EKCalendar? {
        store.calendars(for: .reminder).first { $0.title == name }
    }

    /** Plain copies from a fresh store, since a reminder can't load its alarms once its store is freed. */
    func reminders() async -> [SavedReminder] {
        let store = EKEventStore()
        let reminders = await reminders(in: store)
        return withExtendedLifetime(store) { reminders.map(SavedReminder.init) }
    }

    /** Sorted by title. */
    func reminders(in store: EKEventStore) async -> [EKReminder] {
        guard let calendar = calendar(in: store) else { return [] }
        let predicate = store.predicateForReminders(in: [calendar])
        let ids = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { continuation.resume(returning: $0?.map(\.calendarItemIdentifier) ?? []) }
        }
        return ids.compactMap { store.calendarItem(withIdentifier: $0) as? EKReminder }.sorted { ($0.title ?? "") < ($1.title ?? "") }
    }

    func cleanUp() {
        let store = EKEventStore()
        if let calendar = calendar(in: store) {
            try? store.removeCalendar(calendar, commit: true)
        }
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }
}

/** The service gets its own UserDefaults suite, so tests don't touch the app's saved list. */
func withTestList(_ body: (ReminderService, TestList) async throws -> Void) async throws {
    let list = TestList()
    defer { list.cleanUp() }
    try await body(ReminderService(defaults: UserDefaults(suiteName: list.suiteName)!, listName: list.name, calendar: testCalendar), list)
}

struct SavedReminder {
    let id: String
    let title: String?
    let notes: String?
    let due: Date?
    let alarmDates: [Date?]
    let isCompleted: Bool
    let modified: Date?

    init(_ reminder: EKReminder) {
        id = reminder.calendarItemIdentifier
        title = reminder.title
        notes = reminder.notes
        due = reminder.dueDateComponents.flatMap(testCalendar.date(from:))
        alarmDates = reminder.alarms?.map(\.absoluteDate) ?? []
        isCompleted = reminder.isCompleted
        modified = reminder.lastModifiedDate
    }
}
