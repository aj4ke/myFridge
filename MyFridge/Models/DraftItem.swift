import Foundation

nonisolated struct DraftItem: Identifiable {
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
    var needsRefrigeration: Bool
    var source: ItemSource

    init(
        name: String = "",
        category: FoodCategory = .other,
        quantity: Int = 1,
        weight: (pounds: Double, unit: WeightUnit)? = nil,
        addedDate: Date = Calendar.current.startOfDay(for: .now),
        source: ItemSource = .manual,
        needsRefrigeration: Bool = true,
        calculator: ExpiryCalculator = ExpiryCalculator()
    ) {
        self.isIncluded = needsRefrigeration
        self.name = name
        self.category = category
        self.quantity = quantity
        self.weightPounds = weight?.pounds
        self.weightUnit = weight?.unit ?? .pounds
        self.addedDate = addedDate
        self.expiryDate = calculator.expiry(for: category, named: name, addedOn: addedDate)
        self.needsRefrigeration = needsRefrigeration
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
        self.expiryEdited = item.expiryDate != calculator.expiry(for: item.category, named: item.name, addedOn: item.addedDate)
        self.needsRefrigeration = true
        self.source = item.source
    }

    mutating func recalculateExpiry(calculator: ExpiryCalculator = ExpiryCalculator()) {
        guard !expiryEdited else { return }
        expiryDate = calculator.expiry(for: category, named: name, addedOn: addedDate)
    }

    mutating func setAddedDate(_ date: Date, calculator: ExpiryCalculator = ExpiryCalculator()) {
        addedDate = date
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
    }
}
