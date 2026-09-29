import Foundation
import SwiftData

/** Also remembers the shelf life when an expiry was set by hand. */
enum FridgeItemStore {
    static func add(_ draft: DraftItem, to context: ModelContext, calculator: ExpiryCalculator = ExpiryCalculator()) {
        if draft.expiryEdited {
            calculator.remember(draft)
        }
        let item = FridgeItem(draft)
        context.insert(item)
        Task { await ExpiryAlerts.schedule(for: item) }
    }

    static func update(_ item: FridgeItem, with draft: DraftItem, calculator: ExpiryCalculator = ExpiryCalculator()) {
        if draft.expiryEdited && draft.expiryDate != item.expiryDate {
            calculator.remember(draft)
        }
        item.apply(draft)
        NotificationService.shared.cancel(for: item)
        Task { await ExpiryAlerts.schedule(for: item) }
    }

    static func freeze(_ item: FridgeItem, on date: Date = .now, calculator: ExpiryCalculator = ExpiryCalculator()) {
        var draft = DraftItem(item, calculator: calculator)
        draft.freeze(on: date, calculator: calculator)
        update(item, with: draft, calculator: calculator)
    }

    static func thaw(
        _ item: FridgeItem,
        on date: Date = .now,
        modes: StorageModes = .current,
        calculator: ExpiryCalculator = ExpiryCalculator()
    ) {
        var draft = DraftItem(item, calculator: calculator)
        draft.thaw(on: date, modes: modes, calculator: calculator)
        update(item, with: draft, calculator: calculator)
    }

    static func addImported(_ drafts: [DraftItem], to context: ModelContext, calculator: ExpiryCalculator = ExpiryCalculator()) async throws {
        for draft in drafts {
            if draft.expiryEdited {
                calculator.remember(draft)
            }
            context.insert(FridgeItem(draft))
        }
        try context.save()
        let items = try context.fetch(FetchDescriptor<FridgeItem>())
        await ExpiryAlerts.rescheduleAll(items: StorageModes.current.visible(items))
    }

    /** Includes items hidden in turned-off locations. */
    static func deleteAll(from context: ModelContext) throws {
        for item in try context.fetch(FetchDescriptor<FridgeItem>()) {
            ExpiryAlerts.cancel(for: item)
            context.delete(item)
        }
        try context.save()
    }
}
