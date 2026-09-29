#if DEBUG
import Foundation
import SwiftData

/**
 * Debug-only hooks that UI tests turn on with the -uiTesting launch argument.
 * Items live in memory, so tests never touch saved data. The settings reset only runs in the simulator.
 */
enum UITestLaunch {
    static let argument = "-uiTesting"
    static let resetArgument = "-uiTestingReset"

    /** UITEST_ITEMS entries. Days are counted from today. */
    struct Seed: Decodable {
        let name: String
        let category: String
        var location: String?
        var addedDaysAgo: Int?
        var expiresInDays: Int?
    }

    /** UITEST_IMPORT entries. storage is a ParsedStorage case name. */
    struct ImportSeed: Decodable {
        let name: String
        let category: String
        let storage: String
    }

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains(argument)
    }

    /** UITEST_MODES lists the locations to turn on, like "pantry,freezer". */
    static func resetSettingsIfAsked() {
        #if targetEnvironment(simulator)
        guard ProcessInfo.processInfo.arguments.contains(resetArgument) else { return }
        let defaults = UserDefaults.standard
        defaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        let modes = ProcessInfo.processInfo.environment["UITEST_MODES"] ?? ""
        defaults.set(modes.contains("pantry"), forKey: StorageModes.pantryKey)
        defaults.set(modes.contains("freezer"), forKey: StorageModes.freezerKey)
        #endif
    }

    static func makeContainer() -> ModelContainer {
        let container = try! ModelContainer(for: FridgeItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let today = Calendar.current.startOfDay(for: .now)
        for seed in decode([Seed].self, from: "UITEST_ITEMS") ?? [] {
            var draft = DraftItem(
                name: seed.name,
                category: FoodCategory(rawValue: seed.category)!,
                addedDate: Calendar.current.date(byAdding: .day, value: -(seed.addedDaysAgo ?? 0), to: today)!,
                location: seed.location.flatMap(StorageLocation.init(rawValue:)) ?? .fridge
            )
            if let days = seed.expiresInDays {
                draft.expiryDate = Calendar.current.date(byAdding: .day, value: days, to: today)!
            }
            container.mainContext.insert(FridgeItem(draft))
        }
        return container
    }

    static var importItems: [ParsedItem]? {
        decode([ImportSeed].self, from: "UITEST_IMPORT")?.enumerated().map { index, seed in
            let storage: ParsedStorage = switch seed.storage {
            case "pantry": .pantry
            case "freezer": .freezer
            case "notFood": .notFood
            default: .fridge
            }
            return ParsedItem(line: index + 1, name: seed.name, storage: storage, category: FoodCategory(rawValue: seed.category)!, quantity: 1)
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from key: String) -> T? {
        guard let json = ProcessInfo.processInfo.environment[key] else { return nil }
        return try! JSONDecoder().decode(type, from: Data(json.utf8))
    }
}
#endif
