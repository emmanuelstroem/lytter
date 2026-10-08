//
//  ShowScheduleRefresh.swift
//  lytter
//

import Foundation
import os
#if os(iOS) || os(tvOS) || os(visionOS)
import BackgroundTasks
#endif

/// Runs the show schedule's daily refresh when the app is not in front (F33).
///
/// Neither iOS nor tvOS will start an app at an exact time, so 05:05 Copenhagen time — just
/// after DR's broadcast day turns — is the earliest a background app refresh may begin, and
/// the system picks the moment after that. Launch and returning to the foreground check too
/// (`DRServiceManager.setAppActive`), so a device the system never wakes is still current
/// as soon as it is opened. The Mac has no `BGTaskScheduler`; while the app runs, an
/// `NSBackgroundActivityScheduler` asks every hour, and the refresh does nothing until the
/// day has turned. Each pass ends by scheduling show reminders afresh (F51), so a week of
/// them is booked even on a device that is opened once a week.
enum ShowScheduleRefresh {
    static let identifier = "com.eopio.lytter.show-schedule"

    #if os(iOS) || os(tvOS) || os(visionOS)
    /// Asks for the next refresh at or after the coming 05:05. Submitting again replaces the
    /// request, so this is safe to call whenever the app leaves the foreground.
    static func schedule(now: Date = Date()) {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = BroadcastClock.nextRefresh(after: now)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Log.network.warning(
                "could not schedule the show schedule refresh: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The background task's work: book tomorrow's, then fetch today's. If the system ends
    /// the task early, the refresh stops between channels, and what was fetched is kept.
    static func run() async {
        schedule()
        let manager = DRServiceManager.shared
        // Woken from cold, the catalogue may not be loaded yet; give it a moment.
        for _ in 0..<20 where manager.availableChannels.isEmpty {
            try? await Task.sleep(for: .milliseconds(500))
        }
        let refresh = manager.refreshShowSchedule(inBackground: true)
        await withTaskCancellationHandler {
            await refresh.value
        } onCancel: {
            Task { @MainActor in DRServiceManager.shared.showSchedule.cancelRefresh() }
        }
    }
    #endif

    #if os(macOS)
    private static var scheduler: NSBackgroundActivityScheduler?

    /// Starts the hourly check while the app runs. Once is enough; later calls do nothing.
    static func start() {
        guard scheduler == nil else { return }
        let activity = NSBackgroundActivityScheduler(identifier: identifier)
        activity.repeats = true
        activity.interval = 60 * 60
        activity.tolerance = 15 * 60
        activity.qualityOfService = .utility
        activity.schedule { completion in
            Task { @MainActor in
                await DRServiceManager.shared.refreshShowSchedule(inBackground: true).value
                completion(.finished)
            }
        }
        scheduler = activity
    }
    #endif
}
