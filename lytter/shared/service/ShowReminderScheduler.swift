//
//  ShowReminderScheduler.swift
//  lytter
//

import Foundation
import os
#if os(iOS) || os(macOS)
import UserNotifications

/// What the reminder pass needs from the notification centre, so that the pass can be
/// tested without the system (F51).
protocol ReminderNotificationCenter: AnyObject {
    func pendingIdentifiers() async -> [String]
    func removePending(withIdentifiers identifiers: [String])
    func isAuthorized() async -> Bool
    func schedule(_ reminder: PlannedReminder, body: String) async throws
}

/// Schedules reminders before favourite shows start, as local notifications (F51).
///
/// Local, not push: push would need a server that knows every device's favourites and polls
/// DR for them, and this app has no server. Every pass replaces what the last one scheduled
/// — the app's own pending reminders removed, the plan scheduled afresh — so a programme
/// that moved does not ring twice and a prediction the real schedule contradicts is gone.
final class ShowReminderScheduler {
    private let center: ReminderNotificationCenter

    init(center: ReminderNotificationCenter = SystemReminderCenter()) {
        self.center = center
    }

    /// Replaces the pending reminders with `plan`, or with none when reminders are off or
    /// notifications are not allowed. Leaves any other notification alone.
    func reschedule(_ plan: [PlannedReminder], enabled: Bool,
                    channelTitle: (String) -> String) async {
        let pending = await center.pendingIdentifiers()
            .filter { $0.hasPrefix(ShowReminderPlanner.identifierPrefix) }
        if !pending.isEmpty { center.removePending(withIdentifiers: pending) }
        guard enabled, !plan.isEmpty, await center.isAuthorized() else { return }

        for reminder in plan {
            do {
                try await center.schedule(reminder,
                                          body: reminder.body(channelTitle: channelTitle(reminder.channelSlug)))
            } catch {
                Log.playback.error(
                    "could not schedule a show reminder: \(error.localizedDescription, privacy: .public)")
            }
        }
        Log.playback.info("scheduled \(plan.count, privacy: .public) show reminders")
    }

    /// Asks to send notifications. Called when reminders are first switched on, not at launch.
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Whether notifications have been refused, so Settings can say so and link there.
    static func isDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }
}

/// The real notification centre.
final class SystemReminderCenter: ReminderNotificationCenter {
    private var center: UNUserNotificationCenter { .current() }

    func pendingIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    func removePending(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func isAuthorized() async -> Bool {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional: true
        default: false
        }
    }

    func schedule(_ reminder: PlannedReminder, body: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = reminder.showTitle
        content.body = body
        content.sound = .default
        content.threadIdentifier = "show-reminders"
        content.userInfo = [ReminderNotificationDelegate.channelSlugKey: reminder.channelSlug]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: reminder.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await center.add(UNNotificationRequest(identifier: reminder.identifier,
                                                   content: content, trigger: trigger))
    }
}

/// Opens the app playing the reminder's channel when one is tapped, and shows a reminder
/// that arrives while the app is in front, which the system otherwise keeps quiet.
///
/// Set as the centre's delegate as the app starts, so a tap that launches the app is not
/// missed. The tap becomes a deep link, the way a Top Shelf item or a shortcut plays a
/// channel; one that arrives before the scene can take it is held until it can.
final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderNotificationDelegate()
    nonisolated static let channelSlugKey = "channelSlug"

    private var pendingURL: URL?

    /// Where tapped reminders go. Set by the scene; a reminder tapped before then is handed
    /// over as soon as it is.
    var onOpen: ((URL) -> Void)? {
        didSet {
            if let onOpen, let pendingURL {
                self.pendingURL = nil
                onOpen(pendingURL)
            }
        }
    }

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        guard let slug = response.notification.request.content
                .userInfo[Self.channelSlugKey] as? String else { return }
        await MainActor.run { openChannel(slug: slug) }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Hands the reminder's channel on as a deep link, or holds it until there is somewhere
    /// to hand it. Internal for tests; the system calls `didReceive`.
    func openChannel(slug: String) {
        guard let url = URL(string: "\(DeepLinkHandler.urlScheme):///channel/\(slug)") else { return }
        if let onOpen {
            onOpen(url)
        } else {
            pendingURL = url
        }
    }
}
#endif
