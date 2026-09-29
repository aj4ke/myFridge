import Foundation

nonisolated struct DraftItem: Identifiable {
    /** Why an import starts unchecked and hidden in the review. */
    enum SkipReason: Equatable {
        case notFood
        case locationOff(StorageLocation)
    }

    let id = UUID()
    var isIncluded: Bool
    var name: String
    var category: FoodCategory
    var subcategory: String?
    var quantity: Int
    var weightPounds: Double?
    var weightUnit: WeightUnit
    var addedDate: Date
    var expiryDate: Date
    var expiryEdited = false
    var location: StorageLocation
    var frozenDate: Date?
    var thawedDate: Date?
    var skipReason: SkipReason?
    var source: ItemSource

    init(
        name: String = "",
        category: FoodCategory = .other,
        quantity: Int = 1,
        weight: (pounds: Double, unit: WeightUnit)? = nil,
        addedDate: Date = Calendar.current.startOfDay(for: .now),
        location: StorageLocation = .fridge,
        source: ItemSource = .manual,
        skipReason: SkipReason? = nil,
        calculator: ExpiryCalculator = ExpiryCalculator()
    ) {
        self.isIncluded = skipReason == nil
        self.name = name
        self.category = category
        self.quantity = quantity
        self.weightPounds = weight?.pounds
        self.weightUnit = weight?.unit ?? .pounds
        self.addedDate = addedDate
        self.location = location
        self.frozenDate = location == .freezer ? addedDate : nil
        self.expiryDate = calculator.expiry(for: category, named: name, in: location, addedOn: addedDate)
        self.skipReason = skipReason
        self.source = source
    }

    /** An expiry that doesn't match the calculated one was set by hand. */
    @MainActor
    init(_ item: FridgeItem, calculator: ExpiryCalculator = ExpiryCalculator()) {
        self.isIncluded = true
        self.name = item.name
        self.category = item.category
        self.subcategory = item.subcategory
        self.quantity = item.quantity
        self.weightPounds = item.weightPounds
        self.weightUnit = item.weightUnit
        self.addedDate = item.addedDate
        self.expiryDate = item.expiryDate
        self.location = item.location
        self.frozenDate = item.frozenDate
        self.thawedDate = item.thawedDate
        self.source = item.source
        self.expiryEdited = item.expiryDate != calculator.expiry(for: self)
    }

    mutating func recalculateExpiry(calculator: ExpiryCalculator = ExpiryCalculator()) {
        guard !expiryEdited else { return }
        expiryDate = calculator.expiry(for: self)
    }

    /** Food bought frozen counts from the purchase date, so its frozen date moves with it. Nothing is frozen before it's bought. */
    mutating func setAddedDate(_ date: Date, calculator: ExpiryCalculator = ExpiryCalculator()) {
        if let frozenDate, frozenDate == addedDate || frozenDate < date {
            self.frozenDate = date
        }
        addedDate = date
        recalculateExpiry(calculator: calculator)
    }

    /** Freezer time counts from the day it's frozen, however long it was in the fridge before. */
    mutating func freeze(on date: Date, calculator: ExpiryCalculator = ExpiryCalculator()) {
        location = .freezer
        frozenDate = calculator.calendar.startOfDay(for: date)
        thawedDate = nil
        expiryEdited = false
        recalculateExpiry(calculator: calculator)
    }

    /** For a new item that was never really frozen, like an import marked frozen by mistake. */
    mutating func unfreeze(modes: StorageModes, calculator: ExpiryCalculator = ExpiryCalculator()) {
        location = category.thawDestination(modes)
        frozenDate = nil
        expiryEdited = false
        recalculateExpiry(calculator: calculator)
    }

    mutating func thaw(on date: Date, modes: StorageModes, calculator: ExpiryCalculator = ExpiryCalculator()) {
        location = category.thawDestination(modes)
        frozenDate = nil
        thawedDate = calculator.calendar.startOfDay(for: date)
        expiryEdited = false
        recalculateExpiry(calculator: calculator)
    }
}

extension FridgeItem {
    convenience init(_ draft: DraftItem) {
        self.init(
            name: draft.name,
            category: draft.category,
            subcategory: draft.subcategory,
            quantity: draft.quantity,
            weightPounds: draft.weightPounds,
            weightUnit: draft.weightUnit,
            addedDate: draft.addedDate,
            expiryDate: draft.expiryDate,
            location: draft.location,
            frozenDate: draft.frozenDate,
            thawedDate: draft.thawedDate,
            source: draft.source
        )
    }

    func apply(_ draft: DraftItem) {
        name = draft.name
        category = draft.category
        subcategory = draft.subcategory
        quantity = draft.quantity
        weightPounds = draft.weightPounds
        weightUnit = draft.weightUnit
        addedDate = draft.addedDate
        expiryDate = draft.expiryDate
        location = draft.location
        frozenDate = draft.frozenDate
        thawedDate = draft.thawedDate
    }
}
