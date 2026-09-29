import Foundation

nonisolated enum StorageLocation: String, CaseIterable {
    case fridge
    case pantry
    case freezer

    var displayName: String {
        switch self {
        case .fridge: "Fridge"
        case .pantry: "Pantry"
        case .freezer: "Freezer"
        }
    }

    var symbolName: String {
        switch self {
        case .fridge: "refrigerator.fill"
        case .pantry: "cabinet.fill"
        case .freezer: "snowflake"
        }
    }
}
