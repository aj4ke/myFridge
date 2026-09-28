import Foundation
import Testing
@testable import MyFridge

struct PurchaseDateExtractorTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 12))!
    }

    func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func extract(_ lines: [String]) -> Date? {
        PurchaseDateExtractor.date(in: lines, now: now, calendar: calendar)
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

    @Test(arguments: [
        "Purchased on Monday, September 20, 2026",
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
}
