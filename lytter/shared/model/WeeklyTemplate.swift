//
//  WeeklyTemplate.swift
//  lytter
//

import Foundation

/// DR's clock: Copenhagen time, and a broadcast day that starts at five in the morning.
///
/// Kept as wall-clock times in `Europe/Copenhagen` rather than UTC offsets, so that what is
/// stored as "Mondays 07:05" stays 07:05 across the change to and from summer time.
nonisolated enum BroadcastClock {
    static let timeZone = TimeZone(identifier: "Europe/Copenhagen") ?? .current

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }()

    /// When DR's broadcast day turns. Today's day runs from 05:00 Copenhagen time.
    static let dayStartHour = 5

    /// When the new day is worth fetching: five minutes after it starts, so it is there.
    /// Checked 2026-10-05 against summer time (03:00 UTC); worth checking again after the
    /// change to winter time on 25 October 2026 that DR's day then starts at 04:00 UTC.
    static let refreshHour = 5
    static let refreshMinute = 5

    /// The most recent 05:05 at or before `date`. Anything fetched before it belongs to an
    /// earlier broadcast day.
    static func latestRefresh(atOrBefore date: Date) -> Date {
        let today = calendar.date(bySettingHour: refreshHour, minute: refreshMinute, second: 0,
                                  of: date) ?? date
        if today <= date { return today }
        return calendar.date(byAdding: .day, value: -1, to: today) ?? today
    }

    /// The first 05:05 after `date`.
    static func nextRefresh(after date: Date) -> Date {
        let latest = latestRefresh(atOrBefore: date)
        return calendar.date(byAdding: .day, value: 1, to: latest) ?? latest
    }

    /// Whether something fetched at `fetched` is still today's, at `now`.
    static func isCurrent(fetchedAt fetched: Date?, now: Date) -> Bool {
        guard let fetched else { return false }
        return fetched >= latestRefresh(atOrBefore: now)
    }

    /// The calendar date in Copenhagen, as DR writes dates: "2026-10-05".
    static func dateKey(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The broadcast day `date` falls in, as a date key. 01:00 on a Tuesday is Monday's.
    static func broadcastDayKey(_ date: Date) -> String {
        dateKey(date.addingTimeInterval(-TimeInterval(dayStartHour) * 3600))
    }

    /// 1 for Sunday through 7 for Saturday, as `Calendar` numbers them.
    static func weekday(_ date: Date) -> Int {
        calendar.component(.weekday, from: date)
    }

    /// Minutes since midnight, Copenhagen time.
    static func minuteOfDay(_ date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// `minute` past midnight on the Copenhagen calendar day containing `day`.
    static func date(onDayOf day: Date, atMinute minute: Int) -> Date? {
        calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day)
    }
}

/// One series seen in one slot of the week: a channel, a weekday and a start time.
///
/// The value side of `StoredTemplateSlot`, so that the folding and predicting can be tested
/// without a database.
nonisolated struct TemplateSlot: Equatable, Hashable {
    let channelSlug: String
    /// 1 for Sunday through 7 for Saturday, Copenhagen time.
    let weekday: Int
    /// Minutes past midnight, Copenhagen time.
    let startMinute: Int
    let seriesID: String
    var title: String
    var imageURL: String?
    var durationSeconds: Int
    /// The Copenhagen dates it was seen there, oldest first, three weeks back at most.
    var seenDates: [String]

    /// What identifies the slot and the series in it — the database's unique key.
    var key: String { Self.key(channelSlug, weekday, startMinute, seriesID) }

    static func key(_ channelSlug: String, _ weekday: Int, _ startMinute: Int,
                    _ seriesID: String) -> String {
        "\(channelSlug)|\(weekday)|\(startMinute)|\(seriesID)"
    }
}

/// A weekly schedule of what repeats, learnt on the device from the day schedules the app
/// fetches (F33).
///
/// Without a key, DR's API answers reliably only for today, but the week repeats: compared
/// slot by slot, each channel's Mondays match each other, regional channels included. So
/// each day's real schedule is folded into its weekday's slots, and a slot predicts a series
/// once the series has held it in two of the last three weeks. Two of three rather than two
/// in a row, so that a one-off neither gets predicted nor knocks the regular programme out.
nonisolated enum WeeklyTemplate {

    /// How many weeks back a sighting counts.
    static let weeks = 3
    /// How many of those weeks a series must have held a slot to be predicted there.
    static let requiredSightings = 2

    /// The oldest date key still inside the window at `now`. A date three weeks ago to the
    /// day falls outside it, so a weekday has at most three dates in the window.
    static func oldestCountedDate(at now: Date) -> String {
        let start = BroadcastClock.calendar.date(byAdding: .day, value: -(weeks * 7 - 1),
                                                 to: now) ?? now
        return BroadcastClock.dateKey(start)
    }

    /// `slots` with `day` folded in: each programme with a series adds its date to its slot,
    /// and refreshes the title, artwork and duration from what DR says now. Sightings that
    /// have aged out of the window are dropped, and with them any slot left with none.
    static func fold(_ day: [DREpisode], into slots: [TemplateSlot], now: Date) -> [TemplateSlot] {
        var byKey = Dictionary(slots.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })

        for episode in day {
            guard let series = episode.series, !series.id.isEmpty,
                  let start = episode.startDate else { continue }
            let weekday = BroadcastClock.weekday(start)
            let minute = BroadcastClock.minuteOfDay(start)
            let key = TemplateSlot.key(episode.channel.slug, weekday, minute, series.id)
            let date = BroadcastClock.dateKey(start)
            let image = episode.squareImageURL ?? episode.primaryImageURL

            if var slot = byKey[key] {
                if !slot.seenDates.contains(date) {
                    slot.seenDates = (slot.seenDates + [date]).sorted()
                }
                slot.title = episode.programmeName
                slot.imageURL = image ?? slot.imageURL
                slot.durationSeconds = Int(episode.duration)
                byKey[key] = slot
            } else {
                byKey[key] = TemplateSlot(channelSlug: episode.channel.slug, weekday: weekday,
                                          startMinute: minute, seriesID: series.id,
                                          title: episode.programmeName, imageURL: image,
                                          durationSeconds: Int(episode.duration),
                                          seenDates: [date])
            }
        }

        let oldest = oldestCountedDate(at: now)
        return byKey.values.compactMap { slot in
            var slot = slot
            slot.seenDates = slot.seenDates.filter { $0 >= oldest }
            return slot.seenDates.isEmpty ? nil : slot
        }
        .sorted { $0.key < $1.key }
    }

    /// Whether `slot` has repeated enough, at `now`, to be predicted.
    static func isPredicted(_ slot: TemplateSlot, at now: Date) -> Bool {
        let oldest = oldestCountedDate(at: now)
        return slot.seenDates.filter { $0 >= oldest }.count >= requiredSightings
    }

    /// The next time `seriesID` is predicted to start after `now`, within the coming week.
    ///
    /// A slot in today's broadcast day is skipped on a channel whose real schedule for today
    /// is known (`realChannels`): there, what DR says is on today is the answer, and the
    /// template's guess about today has nothing to add.
    static func nextPredicted(seriesID: String, in slots: [TemplateSlot],
                              realChannels: Set<String>, after now: Date)
        -> (slot: TemplateSlot, start: Date)? {
        // Eight days, so that a slot whose time today has passed — and, on a channel whose
        // real schedule is known, today's slot — still finds next week's.
        predictedStarts(seriesID: seriesID, in: slots, realChannels: realChannels, after: now,
                        days: 8).first
    }

    /// Every predicted start of `seriesID` after `now` and within `days`, soonest first —
    /// what reminders (F51) are scheduled from. Today's slots on a channel in `realChannels`
    /// are left out, as in `nextPredicted`.
    static func predictedStarts(seriesID: String, in slots: [TemplateSlot],
                                realChannels: Set<String>, after now: Date, days: Int = 7)
        -> [(slot: TemplateSlot, start: Date)] {
        let predicted = slots.filter { $0.seriesID == seriesID && isPredicted($0, at: now) }
        guard !predicted.isEmpty else { return [] }
        let today = BroadcastClock.broadcastDayKey(now)
        let horizon = now.addingTimeInterval(TimeInterval(days) * 24 * 3600)

        var starts: [(slot: TemplateSlot, start: Date)] = []
        for offset in 0...days {
            guard let day = BroadcastClock.calendar.date(byAdding: .day, value: offset,
                                                         to: now) else { continue }
            let weekday = BroadcastClock.weekday(day)
            for slot in predicted where slot.weekday == weekday {
                guard let start = BroadcastClock.date(onDayOf: day, atMinute: slot.startMinute),
                      start > now, start <= horizon else { continue }
                if realChannels.contains(slot.channelSlug),
                   BroadcastClock.broadcastDayKey(start) == today { continue }
                starts.append((slot, start))
            }
        }
        return starts.sorted { $0.start < $1.start }
    }
}
