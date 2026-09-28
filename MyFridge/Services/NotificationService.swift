import Foundation
import UserNotifications

/** iOS caps pending notifications at 64, so only the 60 soonest are scheduled. */
@MainActor
final class NotificationService: NSObject {
    static let shared = NotificationService()

    static let maxScheduled = 60

    nonisolated enum Reminder: String, CaseIterable {
        case goingBadSoon
        case expiresToday
        case expired

        var dayOffset: Int {
            switch self {
            case .goingBadSoon: -ExpiryCalculator.soonThreshold
            case .expiresToday: 0
            case .expired: 1
            }
        }

        func body(for name: String) -> String {
            switch self {
            case .goingBadSoon: "Check your \(name), it may be going bad soon."
            case .expiresToday: "Use your \(name) today, it expires today."
            case .expired: "\(name) has expired."
            }
        }
    }

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func schedule(for item: FridgeItem) async {
        for reminder in Reminder.allCases {
            if let date = Self.fireDate(for: reminder, expiry: item.expiryDate, now: .now) {
                await add(reminder, for: item, at: date)
            }
        }
    }

    func cancel(for item: FridgeItem) {
        let identifiers = Reminder.allCases.map { Self.identifier(for: item, $0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func rescheduleAll(items: [FridgeItem]) async {
        center.removeAllPendingNotificationRequests()
        for upcoming in Self.upcoming(from: items, now: .now) {
            await add(upcoming.reminder, for: upcoming.item, at: upcoming.date)
        }
    }

    private func add(_ reminder: Reminder, for item: FridgeItem, at date: Date) async {
        let content = UNMutableNotificationContent()
        content.body = reminder.body(for: item.name)
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: Self.identifier(for: item, reminder), content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func identifier(for item: FridgeItem, _ reminder: Reminder) -> String {
        "\(item.id.uuidString)-\(reminder.rawValue)"
    }

    nonisolated static func fireDate(for reminder: Reminder, expiry: Date, now: Date, calendar: Calendar = .current) -> Date? {
        let day = calendar.date(byAdding: .day, value: reminder.dayOffset, to: calendar.startOfDay(for: expiry))!
        let fireDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day)!
        return fireDate > now ? fireDate : nil
    }

    static func upcoming(
        from items: [FridgeItem],
        now: Date,
        calendar: Calendar = .current
    ) -> [(item: FridgeItem, reminder: Reminder, date: Date)] {
        let all = items.flatMap { item in
            Reminder.allCases.compactMap { reminder in
                fireDate(for: reminder, expiry: item.expiryDate, now: now, calendar: calendar)
                    .map { (item: item, reminder: reminder, date: $0) }
            }
        }
        return Array(all.sorted { $0.date < $1.date }.prefix(maxScheduled))
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    /** Without this, iOS hides notifications while the app is in the foreground. */
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
