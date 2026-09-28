import Foundation
import FoundationModels

/** Raw values are the keys in shelf_life.json. @Generable limits the model to these cases. */
@Generable
nonisolated enum FoodCategory: String, CaseIterable {
    case dairyMilk = "dairy_milk"
    case dairyMilkUltra = "dairy_milk_ultra"
    case dairyYogurt = "dairy_yogurt"
    case cheeseHard = "cheese_hard"
    case cheeseSoft = "cheese_soft"
    case eggs
    case meatRaw = "meat_raw"
    case poultryRaw = "poultry_raw"
    case seafoodRaw = "seafood_raw"
    case meatDeli = "meat_deli"
    case produceLeafy = "produce_leafy"
    case produceBerries = "produce_berries"
    case produceOther = "produce_other"
    case fruitWhole = "fruit_whole"
    case herbs
    case tofuTempeh = "tofu_tempeh"
    case preparedMeals = "prepared_meals"
    case leftovers
    case condiments
    case beverages
    case other

    var displayName: String {
        switch self {
        case .dairyMilk: "Milk"
        case .dairyMilkUltra: "Ultra-Pasteurized Milk"
        case .dairyYogurt: "Yogurt"
        case .cheeseHard: "Hard Cheese"
        case .cheeseSoft: "Soft Cheese"
        case .eggs: "Eggs"
        case .meatRaw: "Raw Meat"
        case .poultryRaw: "Raw Poultry"
        case .seafoodRaw: "Raw Seafood"
        case .meatDeli: "Deli Meat"
        case .produceLeafy: "Leafy Greens"
        case .produceBerries: "Berries"
        case .produceOther: "Other Produce"
        case .fruitWhole: "Whole Fruit"
        case .herbs: "Herbs"
        case .tofuTempeh: "Tofu & Tempeh"
        case .preparedMeals: "Prepared Meals"
        case .leftovers: "Leftovers"
        case .condiments: "Condiments"
        case .beverages: "Beverages"
        case .other: "Other"
        }
    }

    var tracksWeight: Bool {
        switch self {
        case .meatRaw, .poultryRaw, .seafoodRaw, .meatDeli: true
        default: false
        }
    }

    var symbolName: String {
        switch self {
        case .dairyMilk: "drop.fill"
        case .dairyMilkUltra: "drop.circle.fill"
        case .dairyYogurt: "spoon.serving"
        case .cheeseHard: "triangle.fill"
        case .cheeseSoft: "triangle"
        case .eggs: "oval.portrait.fill"
        case .meatRaw: "fork.knife"
        case .poultryRaw: "bird.fill"
        case .seafoodRaw: "fish.fill"
        case .meatDeli: "square.stack.fill"
        case .produceLeafy: "leaf.fill"
        case .produceBerries: "circle.hexagongrid.fill"
        case .produceOther: "carrot.fill"
        case .fruitWhole: "basket.fill"
        case .herbs: "laurel.leading"
        case .tofuTempeh: "cube.fill"
        case .preparedMeals: "takeoutbag.and.cup.and.straw.fill"
        case .leftovers: "microwave.fill"
        case .condiments: "flask.fill"
        case .beverages: "waterbottle.fill"
        case .other: "refrigerator.fill"
        }
    }
}
