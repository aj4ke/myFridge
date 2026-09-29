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

    func expiry(for category: FoodCategory, named name: String = "", in location: StorageLocation = .fridge, addedOn addedDate: Date) -> Date {
        startOfDay(adding: days(for: category, named: name, in: location), to: addedDate)
    }

    /** Frozen items count from the day they were frozen, thawed ones from the day they were thawed. */
    func expiry(for draft: DraftItem) -> Date {
        if let thawedDate = draft.thawedDate {
            return startOfDay(adding: thawedDays(for: draft.category, named: draft.name, returningTo: draft.location), to: thawedDate)
        }
        return expiry(for: draft.category, named: draft.name, in: draft.location, addedOn: draft.frozenDate ?? draft.addedDate)
    }

    func days(for category: FoodCategory, named name: String, in location: StorageLocation = .fridge) -> Int {
        memory.days(for: name, in: location)
            ?? foods.days(for: name, category: category, in: location)
            ?? shelfLife.days(for: category, in: location)
    }

    /** Foods without a USDA thawed limit keep their normal shelf life where they end up. */
    func thawedDays(for category: FoodCategory, named name: String, returningTo location: StorageLocation) -> Int {
        foods.thawedDays(for: name, category: category)
            ?? shelfLife.thawedDays(for: category)
            ?? days(for: category, named: name, in: location)
    }

    /** Thawed items aren't learned, since their days are a short USDA limit rather than a shelf life. */
    func remember(_ draft: DraftItem) {
        guard draft.thawedDate == nil else { return }
        memory.remember(daysLeft(until: draft.expiryDate, now: draft.frozenDate ?? draft.addedDate), for: draft.name, in: draft.location)
    }

    /** Freezing is always allowed. These are shown as warnings. Pass the expiry from before freezing, if known. */
    func freezeWarnings(for category: FoodCategory, named name: String, expiringOn expiry: Date?, frozenOn frozenDate: Date) -> [String] {
        var warnings: [String] = []
        if let expiry, daysLeft(until: expiry, now: frozenDate) < 0 {
            var style = Date.FormatStyle.dateTime.month(.abbreviated).day()
            style.timeZone = calendar.timeZone
            warnings.append("This expired on \(expiry.formatted(style)). Freezing won't make it safe to eat.")
        }
        if FoodShelfLife.freezesPoorly(category, named: name) {
            warnings.append("This food doesn't freeze well. It stays safe but can turn limp or mushy.")
        }
        return warnings
    }

    private func startOfDay(adding days: Int, to date: Date) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: days, to: date)!)
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
