import Foundation

nonisolated enum ExpiryStatus {
    case fresh
    case soon
    case expired
}

nonisolated struct ExpiryCalculator {
    static let soonThreshold = 2

    var shelfLife: ShelfLifeService = .shared
    var foods: FoodShelfLife = .shared
    var memory: ShelfLifeMemory = .shared
    var calendar: Calendar = .current

    func expiry(for category: FoodCategory, named name: String = "", addedOn addedDate: Date) -> Date {
        let expiry = calendar.date(byAdding: .day, value: days(for: category, named: name), to: addedDate)!
        return calendar.startOfDay(for: expiry)
    }

    func days(for category: FoodCategory, named name: String) -> Int {
        memory.days(for: name) ?? foods.days(for: name, category: category) ?? shelfLife.days(for: category)
    }

    func remember(_ draft: DraftItem) {
        memory.remember(daysLeft(until: draft.expiryDate, now: draft.addedDate), for: draft.name)
    }

    func daysLeft(until expiry: Date, now: Date = .now) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: expiry)).day!
    }

    func status(for expiry: Date, now: Date = .now) -> ExpiryStatus {
        switch daysLeft(until: expiry, now: now) {
        case ..<0: .expired
        case 0...Self.soonThreshold: .soon
        default: .fresh
        }
    }

    func relativeText(for expiry: Date, now: Date = .now) -> String {
        let days = daysLeft(until: expiry, now: now)
        switch days {
        case ..<(-1): return "Expired \(-days) days ago"
        case -1: return "Expired yesterday"
        case 0: return "Expires today"
        case 1: return "Expires tomorrow"
        default: return "\(days) days left"
        }
    }
}
