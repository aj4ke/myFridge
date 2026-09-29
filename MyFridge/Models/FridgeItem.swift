import Foundation
import SwiftData

/** Enums are stored as raw strings and wrapped by the computed properties. */
@Model
final class FridgeItem {
    var id: UUID
    var name: String
    var categoryRaw: String
    var quantity: Int
    var addedDate: Date
    var expiryDate: Date
    var sourceRaw: String
    var notes: String?
    var subcategory: String?
    var weightPounds: Double?
    var weightUnitRaw: String?
    var locationRaw: String?
    var frozenDate: Date?
    var thawedDate: Date?

    var category: FoodCategory {
        get { FoodCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var weightUnit: WeightUnit {
        get { weightUnitRaw.flatMap(WeightUnit.init(rawValue:)) ?? .pounds }
        set { weightUnitRaw = newValue.rawValue }
    }

    var source: ItemSource {
        get { ItemSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    /** Items saved before pantry and freezer existed have no location and are in the fridge. */
    var location: StorageLocation {
        get { locationRaw.flatMap(StorageLocation.init(rawValue:)) ?? .fridge }
        set { locationRaw = newValue.rawValue }
    }

    init(
        name: String,
        category: FoodCategory,
        subcategory: String? = nil,
        quantity: Int = 1,
        weightPounds: Double? = nil,
        weightUnit: WeightUnit = .pounds,
        addedDate: Date = .now,
        expiryDate: Date,
        location: StorageLocation = .fridge,
        frozenDate: Date? = nil,
        thawedDate: Date? = nil,
        source: ItemSource = .manual,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.categoryRaw = category.rawValue
        self.subcategory = subcategory
        self.quantity = quantity
        self.weightPounds = weightPounds
        self.weightUnitRaw = weightUnit.rawValue
        self.addedDate = addedDate
        self.expiryDate = expiryDate
        self.locationRaw = location.rawValue
        self.frozenDate = frozenDate
        self.thawedDate = thawedDate
        self.sourceRaw = source.rawValue
        self.notes = notes
    }
}
