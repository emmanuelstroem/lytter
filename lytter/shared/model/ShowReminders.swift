//
//  ShowReminders.swift
//  lytter
//

import Foundation

/// One reminder to schedule: a favourite show about to start (F51).
nonisolated struct PlannedReminder: Equatable {
    /// `ShowReminderPlanner.identifierPrefix` + channel + start. The same for a predicted and
    /// a real airing at one time on one channel, so the real one replaces the guess, and a
    /// programme that moves gets a new identifier rather than ringing twice.
    let identifier: String
    let fireDate: Date
    let start: Date
    let seriesID: String
    let showTitle: String
    let channelSlug: String
    /// From the weekly template rather than today's real schedule, and said as such.
    let isPredicted: Bool
}

/// Decides which reminders to schedule (F51): a pure function of favourite shows, today's
/// real airings, the weekly template, the time and the lead time, so it can be tested
/// without the notification centre.
///
/// It covers the coming seven days, so a device that runs the app once a week still rings:
/// today's real airings, and the template's repeated slots for every other day. Each pass
/// replaces what the last scheduled, so a prediction is confirmed, moved or dropped once
/// that day's real schedule has been fetched.
nonisolated enum ShowReminderPlanner {

    /// What every reminder identifier starts with, so a pass removes only its own.
    static let identifierPrefix = "show-reminder|"

    /// How long before the start a reminder rings.
    static let leadTime: TimeInterval = 5 * 60

    /// iOS keeps at most 64 pending notifications per app and drops the rest silently.
    static let limit = 60

    static func identifier(channelSlug: String, start: Date) -> String {
        "\(identifierPrefix)\(channelSlug)|\(Int(start.timeIntervalSince1970))"
    }

    /// - Parameters:
    ///   - today: today's real schedules by channel slug, for the channels fetched.
    ///   - slots: the template's slots for the favourite shows.
    static func plan(shows: [FavouriteShow], today: [String: [DREpisode]],
                     slots: [TemplateSlot], now: Date, leadTime: TimeInterval = leadTime,
                     days: Int = 7, limit: Int = limit) -> [PlannedReminder] {
        let titles = Dictionary(shows.map { ($0.seriesID, $0.title) },
                                uniquingKeysWith: { first, _ in first })
        var byIdentifier: [String: PlannedReminder] = [:]

        for (seriesID, title) in titles {
            for (slot, start) in WeeklyTemplate.predictedStarts(
                seriesID: seriesID, in: slots, realChannels: Set(today.keys), after: now,
                days: days) {
                let reminder = PlannedReminder(
                    identifier: identifier(channelSlug: slot.channelSlug, start: start),
                    fireDate: start.addingTimeInterval(-leadTime), start: start,
                    seriesID: seriesID, showTitle: title, channelSlug: slot.channelSlug,
                    isPredicted: true)
                byIdentifier[reminder.identifier] = reminder
            }
        }

        // After the predictions, so a real airing at the same time replaces the guess.
        for episode in today.values.joined() {
            guard let seriesID = episode.series?.id, let title = titles[seriesID],
                  let start = episode.startDate else { continue }
            let reminder = PlannedReminder(
                identifier: identifier(channelSlug: episode.channel.slug, start: start),
                fireDate: start.addingTimeInterval(-leadTime), start: start,
                seriesID: seriesID, showTitle: title, channelSlug: episode.channel.slug,
                isPredicted: false)
            byIdentifier[reminder.identifier] = reminder
        }

        // Only what can still ring: a reminder whose moment has passed would fire at once,
        // for a programme already starting.
        return byIdentifier.values
            .filter { $0.fireDate > now }
            .sorted { ($0.fireDate, $0.identifier) < ($1.fireDate, $1.identifier) }
            .prefix(limit)
            .map { $0 }
    }
}

extension PlannedReminder {
    /// "Starts at 07:05 on P1", or "Usually starts at 07:05 on P1" for a prediction. The time
    /// rather than "now": the reminder rings a few minutes early.
    func body(channelTitle: String) -> String {
        let time = start.formatted(date: .omitted, time: .shortened)
        return isPredicted
            ? String(localized: "Usually starts at \(time) on \(channelTitle)")
            : String(localized: "Starts at \(time) on \(channelTitle)")
    }
}
