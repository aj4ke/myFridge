import Foundation
import Testing
@testable import MyFridge

struct NotificationServiceTests {
    let calculator = ExpiryCalculator.testing()

    func fireDate(_ reminder: NotificationService.Reminder, expiry: Date, now: Date) -> Date? {
        NotificationService.fireDate(for: reminder, expiry: expiry, now: now, calendar: testCalendar)
    }

    func upcoming(_ items: [FridgeItem], now: Date) -> [(item: FridgeItem, reminder: NotificationService.Reminder, date: Date)] {
        NotificationService.upcoming(from: items, now: now, calendar: testCalendar)
    }

    @Test func goingBadSoonFiresTheMorningItTurnsYellow() {
        let expiry = date(2026, 9, 26)
        #expect(fireDate(.goingBadSoon, expiry: expiry, now: date(2026, 9, 20)) == date(2026, 9, 24, hour: 9))
        #expect(calculator.status(for: expiry, now: date(2026, 9, 24, hour: 9)) == .soon)
        #expect(calculator.status(for: expiry, now: date(2026, 9, 23, hour: 23)) == .fresh)
    }

    @Test func expiredFiresTheMorningItTurnsRed() {
        let expiry = date(2026, 9, 26)
        #expect(fireDate(.expired, expiry: expiry, now: date(2026, 9, 20)) == date(2026, 9, 27, hour: 9))
        #expect(calculator.status(for: expiry, now: date(2026, 9, 27, hour: 9)) == .expired)
        #expect(calculator.status(for: expiry, now: date(2026, 9, 26, hour: 23)) == .soon)
    }

    @Test func expiresTodayFiresTheMorningOfTheExpiryDate() {
        #expect(fireDate(.expiresToday, expiry: date(2026, 9, 26), now: date(2026, 9, 20)) == date(2026, 9, 26, hour: 9))
    }

    /** Already yellow when added, so goingBadSoon is skipped. */
    @Test func shortLifeItemStillGetsNotifiedOnItsLastDay() {
        let addedThursdayAfternoon = date(2026, 9, 25, hour: 13)
        let salmon = FridgeItem(name: "Salmon", category: .seafoodRaw, expiryDate: date(2026, 9, 27))
        let upcoming = upcoming([salmon], now: addedThursdayAfternoon)
        #expect(upcoming.map(\.reminder) == [.expiresToday, .expired])
        #expect(upcoming.map(\.date) == [date(2026, 9, 27, hour: 9), date(2026, 9, 28, hour: 9)])
    }

    @Test func firesAcrossMonthBoundaries() {
        #expect(fireDate(.goingBadSoon, expiry: date(2026, 10, 1), now: date(2026, 9, 20)) == date(2026, 9, 29, hour: 9))
        #expect(fireDate(.expired, expiry: date(2026, 9, 30), now: date(2026, 9, 20)) == date(2026, 10, 1, hour: 9))
    }

    /** 2026 daylight saving starts March 8 and ends November 1. Reminders stay at 9 AM local time. */
    @Test func firesAtNineOnDaylightSavingDays() {
        #expect(fireDate(.goingBadSoon, expiry: date(2026, 3, 10), now: date(2026, 3, 1)) == date(2026, 3, 8, hour: 9))
        #expect(fireDate(.expiresToday, expiry: date(2026, 3, 8), now: date(2026, 3, 1)) == date(2026, 3, 8, hour: 9))
        #expect(fireDate(.expiresToday, expiry: date(2026, 11, 1), now: date(2026, 10, 25)) == date(2026, 11, 1, hour: 9))
        #expect(fireDate(.expired, expiry: date(2026, 10, 31), now: date(2026, 10, 25)) == date(2026, 11, 1, hour: 9))
    }

    @Test func stillSchedulesBeforeNine() {
        #expect(fireDate(.goingBadSoon, expiry: date(2026, 9, 25), now: date(2026, 9, 23, hour: 8, minute: 59)) == date(2026, 9, 23, hour: 9))
    }

    @Test func skipsRemindersWhoseTimeHasPassed() {
        let now = date(2026, 9, 23, hour: 9, minute: 30)
        #expect(fireDate(.goingBadSoon, expiry: date(2026, 9, 25), now: now) == nil)
        #expect(fireDate(.expiresToday, expiry: date(2026, 9, 25), now: now) == date(2026, 9, 25, hour: 9))
        #expect(fireDate(.expired, expiry: date(2026, 9, 25), now: now) == date(2026, 9, 26, hour: 9))
        #expect(fireDate(.expired, expiry: date(2026, 9, 21), now: now) == nil)
    }

    @Test func schedulesTheSoonestSixtyNotifications() {
        let now = date(2026, 9, 23, hour: 12)
        func item(expiringIn days: Int) -> FridgeItem {
            FridgeItem(
                name: "Item \(days)",
                category: .other,
                expiryDate: testCalendar.date(byAdding: .day, value: days, to: date(2026, 9, 23))!
            )
        }

        let items = (-5...80).shuffled().map { item(expiringIn: $0) }
        let upcoming = upcoming(items, now: now)

        #expect(upcoming.count == 60)
        #expect(upcoming.map(\.date) == upcoming.map(\.date).sorted())
        #expect(upcoming.allSatisfy { $0.date > now })
        let tomorrowMorning = date(2026, 9, 24, hour: 9)
        #expect(upcoming[0].date == tomorrowMorning)
        let firstBatch = upcoming.filter { $0.date == tomorrowMorning }.map { "\($0.item.name) \($0.reminder)" }
        #expect(Set(firstBatch) == ["Item 0 expired", "Item 1 expiresToday", "Item 3 goingBadSoon"])
    }

    @Test func nothingUpcomingForExpiredOrNoItems() {
        let now = date(2026, 9, 23, hour: 12)
        let old = FridgeItem(name: "Old Milk", category: .dairyMilk, expiryDate: date(2026, 9, 20))
        #expect(upcoming([old], now: now).isEmpty)
        #expect(upcoming([], now: now).isEmpty)
    }

    @Test func identifiersAreUniquePerItemAndReminder() {
        let items = [
            FridgeItem(name: "Milk", category: .dairyMilk, expiryDate: date(2026, 9, 27)),
            FridgeItem(name: "Milk", category: .dairyMilk, expiryDate: date(2026, 9, 27)),
        ]
        let identifiers = items.flatMap { item in
            NotificationService.Reminder.allCases.map { NotificationService.identifier(for: item, $0) }
        }
        #expect(Set(identifiers).count == 6)
    }

    /** FridgeItemStore.update cancels after applying the edit, so the identifier can't depend on edited fields. */
    @Test func identifierSurvivesEdits() {
        let item = FridgeItem(name: "Milk", category: .dairyMilk, expiryDate: date(2026, 9, 27))
        let before = NotificationService.identifier(for: item, .expired)
        item.name = "Oat Milk"
        item.expiryDate = date(2026, 10, 5)
        #expect(NotificationService.identifier(for: item, .expired) == before)
    }

    @Test(arguments: NotificationService.Reminder.allCases)
    func bodyNamesTheItem(_ reminder: NotificationService.Reminder) {
        #expect(reminder.body(for: "Organic Kale").contains("Organic Kale"))
    }
}
