import EventKit
import Foundation

/**
 * Keeps one reminder per item in a MyFridge list in Reminders. The list belongs to the app, so edits made in
 * Reminders are overwritten and reminders the app didn't make are removed on the next sync.
 */
@MainActor
final class ReminderService {
    static let shared = ReminderService()

    static let enabledKey = "remindersEnabled"

    private let store: EKEventStore
    private let defaults: UserDefaults
    private let listName: String
    private let calendar: Calendar
    private var lastSync: Task<Void, any Error>?

    init(store: EKEventStore = EKEventStore(), defaults: UserDefaults = .standard, listName: String = "MyFridge", calendar: Calendar = .current) {
        self.store = store
        self.defaults = defaults
        self.listName = listName
        self.calendar = calendar
    }

    nonisolated static var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.enabledKey) }
        set { defaults.set(newValue, forKey: Self.enabledKey) }
    }

    var isActive: Bool {
        isEnabled && Self.hasAccess
    }

    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToReminders()) ?? false
    }

    /** Due and alerting at 9 AM on the expiry day, when the app's own expires-today notification would fire. */
    nonisolated static func dueDate(forExpiry expiry: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: 9, minute: 0, second: 0, of: calendar.startOfDay(for: expiry))!
    }

    func sync(_ items: [FridgeItem]) async throws {
        let entries = items.map { Entry($0, calendar: calendar) }
        try await enqueue { try await self.reconcile(entries) }
    }

    func save(_ item: FridgeItem) throws {
        let list = try list()
        let entry = Entry(item, calendar: calendar)
        var ids = reminderIDs
        let existing = ids[entry.key].flatMap { store.calendarItem(withIdentifier: $0) as? EKReminder }
        if let existing, matches(existing, entry, in: list) {
            return
        }
        let reminder = existing ?? EKReminder(eventStore: store)
        apply(entry, to: reminder, in: list)
        try store.save(reminder, commit: true)
        ids[entry.key] = reminder.calendarItemIdentifier
        reminderIDs = ids
    }

    func remove(_ item: FridgeItem) throws {
        var ids = reminderIDs
        guard let id = ids.removeValue(forKey: item.id.uuidString) else { return }
        reminderIDs = ids
        if let reminder = store.calendarItem(withIdentifier: id) as? EKReminder {
            try store.remove(reminder, commit: true)
        }
    }

    func deleteList() async throws {
        try await enqueue {
            if let list = self.existingList() {
                try self.store.removeCalendar(list, commit: true)
            }
            self.defaults.removeObject(forKey: self.listIDKey)
            self.defaults.removeObject(forKey: self.reminderIDsKey)
        }
    }

    /**
     * Syncs and deletes run one at a time, in order. Otherwise two syncs could both create a reminder for the same
     * new item, or a sync still in flight could make the list again right after it was deleted.
     */
    private func enqueue(_ work: @escaping () async throws -> Void) async throws {
        let previous = lastSync
        let task = Task {
            _ = await previous?.result
            try await work()
        }
        lastSync = task
        try await task.value
    }

    private func reconcile(_ entries: [Entry]) async throws {
        let list = try list()
        var unclaimed = Dictionary(uniqueKeysWithValues: await reminders(in: list).map { ($0.calendarItemIdentifier, $0) })
        let oldIDs = reminderIDs
        var ids: [String: String] = [:]
        for entry in entries {
            if let id = oldIDs[entry.key], let reminder = unclaimed.removeValue(forKey: id) {
                if !matches(reminder, entry, in: list) {
                    apply(entry, to: reminder, in: list)
                    try store.save(reminder, commit: false)
                }
                ids[entry.key] = id
            } else {
                let reminder = EKReminder(eventStore: store)
                apply(entry, to: reminder, in: list)
                try store.save(reminder, commit: false)
                ids[entry.key] = reminder.calendarItemIdentifier
            }
        }
        for reminder in unclaimed.values {
            try store.remove(reminder, commit: false)
        }
        try store.commit()
        reminderIDs = ids
    }

    private func reminders(in list: EKCalendar) async -> [EKReminder] {
        let predicate = store.predicateForReminders(in: [list])
        /* EKReminder isn't Sendable, so only the ids leave the fetch callback. */
        let ids = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { continuation.resume(returning: $0?.map(\.calendarItemIdentifier) ?? []) }
        }
        return ids.compactMap { store.calendarItem(withIdentifier: $0) as? EKReminder }
    }

    /** Falls back to the title so a reinstall reuses the list instead of making a second one. */
    private func existingList() -> EKCalendar? {
        if let id = defaults.string(forKey: listIDKey), let list = store.calendar(withIdentifier: id) {
            return list
        }
        return store.calendars(for: .reminder).first { $0.title == listName }
    }

    private func list() throws -> EKCalendar {
        let list = try existingList() ?? makeList()
        defaults.set(list.calendarIdentifier, forKey: listIDKey)
        return list
    }

    private func makeList() throws -> EKCalendar {
        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = listName
        list.source = store.defaultCalendarForNewReminders()?.source ?? store.sources.first { $0.sourceType == .local }
        try store.saveCalendar(list, commit: true)
        return list
    }

    private func matches(_ reminder: EKReminder, _ entry: Entry, in list: EKCalendar) -> Bool {
        reminder.calendar?.calendarIdentifier == list.calendarIdentifier
            && reminder.title == entry.title
            && reminder.notes == entry.notes
            && !reminder.isCompleted
            && reminder.dueDateComponents.flatMap(calendar.date(from:)) == entry.due
            && reminder.alarms?.map(\.absoluteDate) == [entry.due]
    }

    private func apply(_ entry: Entry, to reminder: EKReminder, in list: EKCalendar) {
        reminder.calendar = list
        reminder.title = entry.title
        reminder.notes = entry.notes
        reminder.isCompleted = false
        reminder.dueDateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: entry.due)
        reminder.alarms = [EKAlarm(absoluteDate: entry.due)]
    }

    private let listIDKey = "reminderListID"
    private let reminderIDsKey = "reminderIDs"

    /** Item id to reminder id. */
    private var reminderIDs: [String: String] {
        get { defaults.dictionary(forKey: reminderIDsKey) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: reminderIDsKey) }
    }

    /** Read up front, since an item deleted while a sync waits on Reminders can't be read anymore. */
    private struct Entry {
        let key: String
        let title: String
        let notes: String
        let due: Date

        init(_ item: FridgeItem, calendar: Calendar) {
            key = item.id.uuidString
            title = item.name
            notes = item.location.displayName
            due = ReminderService.dueDate(forExpiry: item.expiryDate, calendar: calendar)
        }
    }
}
