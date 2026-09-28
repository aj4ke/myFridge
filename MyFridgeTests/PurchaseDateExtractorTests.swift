import Foundation
import Testing
@testable import MyFridge

struct PurchaseDateExtractorTests {
    func extract(_ lines: [String], now: Date = date(2026, 9, 25, hour: 12)) -> Date? {
        PurchaseDateExtractor.date(in: lines, now: now, calendar: testCalendar)
    }

    @Test func readsReceiptDate() {
        #expect(extract(["WHOLE FOODS MARKET", "09/20/26 10:15 AM", "ORG KALE 2.99"]) == date(2026, 9, 20))
    }

    @Test func readsFourDigitYear() {
        #expect(extract(["9/24/2026"]) == date(2026, 9, 24))
    }

    @Test func acceptsToday() {
        #expect(extract(["09/25/26"]) == date(2026, 9, 25))
    }

    @Test func acceptsExactlyThirtyDaysAgo() {
        #expect(extract(["08/26/26"]) == date(2026, 8, 26))
        #expect(extract(["08/25/26"]) == nil)
    }

    @Test(arguments: [
        "Purchased on Monday, September 20, 2026",
        "PURCHASED ON MONDAY, SEPTEMBER 20, 2026",
        "Sept 20, 2026",
        "sep. 20 2026",
    ])
    func readsWrittenDate(_ line: String) {
        #expect(extract([line]) == date(2026, 9, 20))
    }

    @Test(arguments: [
        "09/30/26",
        "07/01/26",
        "13/45/26",
        "ORG KALE 2.99",
        "Purchased on Wednesday, September 30, 2026",
        "September 31, 2026",
    ])
    func ignoresUnusableDates(_ line: String) {
        #expect(extract([line]) == nil)
    }

    @Test func skipsUnusableDateAndKeepsLooking() {
        #expect(extract(["EXP 12/31/26", "09/20/26 10:15 AM"]) == date(2026, 9, 20))
    }

    @Test func firstUsableDateWins() {
        #expect(extract(["09/20/26", "09/22/26"]) == date(2026, 9, 20))
    }

    @Test func readsLastYearsDateInEarlyJanuary() {
        #expect(extract(["12/28/26"], now: date(2027, 1, 3, hour: 12)) == date(2026, 12, 28))
    }

    @Test func leapDayOnlyCountsInLeapYears() {
        #expect(extract(["02/29/28"], now: date(2028, 3, 5, hour: 12)) == date(2028, 2, 29))
        #expect(extract(["02/29/27"], now: date(2027, 3, 5, hour: 12)) == nil)
    }
}
