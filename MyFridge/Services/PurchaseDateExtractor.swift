import Foundation

nonisolated enum PurchaseDateExtractor {
    static let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

    /** Only dates from the last 30 days count, so a misread can't make everything look expired. */
    static func date(in lines: [String], now: Date = .now, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: now)
        let earliest = calendar.date(byAdding: .day, value: -30, to: today)!
        for line in lines {
            guard let (month, day, year) = components(in: line),
                  let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
                  calendar.component(.month, from: date) == month,
                  (earliest...today).contains(date)
            else { continue }
            return date
        }
        return nil
    }

    /** Receipts print 09/20/26. Amazon order pages write out "Monday, September 28, 2026". */
    private static func components(in line: String) -> (month: Int, day: Int, year: Int)? {
        if let match = line.firstMatch(of: /\b(\d{1,2})\/(\d{1,2})\/(\d{4}|\d{2})\b/),
           let month = Int(match.1), let day = Int(match.2), let year = Int(match.3) {
            return (month, day, year < 100 ? year + 2000 : year)
        }
        let written = /\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(\d{1,2}),?\s+(\d{4})\b/
        if let match = line.firstMatch(of: written.ignoresCase()),
           let month = months.firstIndex(of: match.1.lowercased()), let day = Int(match.2), let year = Int(match.3) {
            return (month + 1, day, year)
        }
        return nil
    }
}
