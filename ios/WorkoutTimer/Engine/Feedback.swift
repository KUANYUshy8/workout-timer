import UIKit
import UserNotifications

enum Haptics {
    static func phase(_ kind: PhaseKind) {
        switch kind {
        case .work: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .rest, .reset: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .prep: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

/// Lock-screen notifications that show which phase just started.
/// They are only shown while the app is not in front; inside the app nothing pops up.
enum PhaseNotifier {
    struct Item {
        let id: String
        let after: TimeInterval
        let title: String
        let body: String
    }

    private static var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

    static func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func schedule(_ items: [Item]) {
        center.removeAllPendingNotificationRequests()
        for item in items where item.after > 0.5 {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.threadIdentifier = "workout"
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: item.after, repeats: false)
            center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
    }

    static func clearPending() {
        center.removeAllPendingNotificationRequests()
    }

    static func clearAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    /// Keeps only the newest phase notification on the lock screen.
    static func removeDelivered(before index: Int) {
        guard index > 0 else { return }
        center.removeDeliveredNotifications(withIdentifiers: (0..<index).map { "phase-\($0)" })
    }
}
