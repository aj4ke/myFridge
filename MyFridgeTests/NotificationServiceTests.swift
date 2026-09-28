import Foundation
import Testing
@testable import MyFridge

struct NotificationServiceTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func fireDate(_ reminder: NotificationService.Reminder, expiry: Date, now: Date) -> Date? {
        NotificationService.fireDate(for: reminder, expiry: expiry, now: now, calendar: calendar)
    }

    @Test func goingBadSoonFiresTheMorningItTurnsYellow() {
        let expiry = date(2026, 9, 26)
        #expect(fireDate(.goingBadSoon, expiry: expiry, now: date(2026, 9, 20)) == date(2026, 9, 24, hour: 9))
        #expect(ExpiryCalculator(calendar: calendar).status(for: expiry, now: date(2026, 9, 24, hour: 9)) == .soon)
        #expect(ExpiryCalculator(calendar: calendar).status(for: expiry, now: date(2026, 9, 23, hour: 23)) == .fresh)
    }

    @Test func expiredFiresTheMorningItTurnsRed() {
        let expiry = date(2026, 9, 26)
        #expect(fireDate(.expired, expiry: expiry, now: date(2026, 9, 20)) == date(2026, 9, 27, hour: 9))
        #expect(ExpiryCalculator(calendar: calendar).status(for: expiry, now: date(2026, 9, 27, hour: 9)) == .expired)
        #expect(ExpiryCalculator(calendar: calendar).status(for: expiry, now: date(2026, 9, 26, hour: 23)) == .soon)
    }

    @Test func expiresTodayFiresTheMorningOfTheExpiryDate() {
        #expect(fireDate(.expiresToday, expiry: date(2026, 9, 26), now: date(2026, 9, 20)) == date(2026, 9, 26, hour: 9))
    }

    /** Already yellow when added, so goingBadSoon is skipped. */
    @Test func shortLifeItemStillGetsNotifiedOnItsLastDay() {
        let addedThursdayAfternoon = date(2026, 9, 25, hour: 13)
        let salmon = FridgeItem(name: "Salmon", category: .seafoodRaw, expiryDate: date(2026, 9, 27))
        let upcoming = NotificationService.upcoming(from: [salmon], now: addedThursdayAfternoon, calendar: calendar)
        #expect(upcoming.map(\.reminder) == [.expiresToday, .expired])
        #expect(upcoming.map(\.date) == [date(2026, 9, 27, hour: 9), date(2026, 9, 28, hour: 9)])
    }

    @Test func firesAcrossMonthBoundaries() {
        #expect(fireDate(.goingBadSoon, expiry: date(2026, 10, 1), now: date(2026, 9, 20)) == date(2026, 9, 29, hour: 9))
        #expect(fireDate(.expired, expiry: date(2026, 9, 30), now: date(2026, 9, 20)) == date(2026, 10, 1, hour: 9))
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
                expiryDate: calendar.date(byAdding: .day, value: days, to: date(2026, 9, 23))!
            )
        }

        let items = (-5...80).shuffled().map { item(expiringIn: $0) }
        let upcoming = NotificationService.upcoming(from: items, now: now, calendar: calendar)

        #expect(upcoming.count == 60)
        #expect(upcoming.map(\.date) == upcoming.map(\.date).sorted())
        #expect(upcoming.allSatisfy { $0.date > now })
        let tomorrowMorning = date(2026, 9, 24, hour: 9)
        #expect(upcoming[0].date == tomorrowMorning)
        let firstBatch = upcoming.filter { $0.date == tomorrowMorning }.map { "\($0.item.name) \($0.reminder)" }
        #expect(Set(firstBatch) == ["Item 0 expired", "Item 1 expiresToday", "Item 3 goingBadSoon"])
    }
}
