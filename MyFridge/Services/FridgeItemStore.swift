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
        Task { await NotificationService.shared.schedule(for: item) }
    }

    static func update(_ item: FridgeItem, with draft: DraftItem, calculator: ExpiryCalculator = ExpiryCalculator()) {
        if draft.expiryEdited && draft.expiryDate != item.expiryDate {
            calculator.remember(draft)
        }
        item.apply(draft)
        NotificationService.shared.cancel(for: item)
        Task { await NotificationService.shared.schedule(for: item) }
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
        await NotificationService.shared.rescheduleAll(items: items)
    }
}
