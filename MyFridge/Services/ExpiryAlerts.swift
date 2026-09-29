import Foundation

/**
 * Expiry alerts go to the MyFridge list in Reminders when syncing is on, and to app notifications otherwise.
 * If Reminders can't be written to, notifications fill in so no item goes without an alert.
 */
enum ExpiryAlerts {
    static func schedule(for item: FridgeItem) async {
        if ReminderService.shared.isActive, (try? ReminderService.shared.save(item)) != nil {
            return
        }
        await NotificationService.shared.schedule(for: item)
    }

    static func cancel(for item: FridgeItem) {
        NotificationService.shared.cancel(for: item)
        if ReminderService.shared.isActive {
            try? ReminderService.shared.remove(item)
        }
    }

    /** Syncing turns off if Reminders access was taken away in the Settings app. */
    static func rescheduleAll(items: [FridgeItem]) async {
        let reminders = ReminderService.shared
        if reminders.isEnabled && !ReminderService.hasAccess {
            reminders.isEnabled = false
        }
        if reminders.isActive, (try? await reminders.sync(items)) != nil {
            /* Clears the app's own notifications. */
            await NotificationService.shared.rescheduleAll(items: [])
        } else {
            await NotificationService.shared.rescheduleAll(items: items)
        }
    }
}
