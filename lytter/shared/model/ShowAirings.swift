//
//  ShowAirings.swift
//  lytter
//

import Foundation

/// When a favourite show is next on, as far as the app can tell (F33).
nonisolated enum ShowAiring: Equatable {
    /// On air now, from today's real schedule.
    case onNow(DREpisode)
    /// Later in today's broadcast day, from today's real schedule.
    case laterToday(DREpisode)
    /// Not on again today, but it has held a slot in two of the last three weeks: the next
    /// time that slot comes round. A prediction, and said as one.
    case usually(TemplateSlot, next: Date)
    /// On earlier today, with a recording to listen back to (F16).
    case earlierToday(DREpisode)
    /// Today's schedule is known for its channels, and it is not on again.
    case notOnAgainToday
    /// None of its channels' schedules for today are known yet, and nothing is predicted.
    case unknown

    /// The channel the airing is on, by slug, where there is one.
    var channelSlug: String? {
        switch self {
        case .onNow(let episode), .laterToday(let episode), .earlierToday(let episode):
            episode.channel.slug
        case .usually(let slot, _):
            slot.channelSlug
        case .notOnAgainToday, .unknown:
            nil
        }
    }

    /// The answer for `seriesID`, in order: on now, else later today, else the next
    /// predicted airing this week, else the last one today if it can be listened back to.
    ///
    /// - Parameters:
    ///   - today: today's real schedules, by channel slug — only the channels fetched.
    ///   - slots: the weekly template's slots for this series.
    ///   - channelSlugs: the channels the show has been seen on, to tell "not on again"
    ///     from "not known yet".
    static func next(for seriesID: String, today: [String: [DREpisode]],
                     slots: [TemplateSlot], channelSlugs: [String], now: Date) -> ShowAiring {
        let all: [DREpisode] = today.values.flatMap { $0 }
        let airings = all
            .filter { $0.series?.id == seriesID }
            .sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }

        if let onNow = airings.first(where: { $0.isPlaying(at: now) }) {
            return .onNow(onNow)
        }
        if let later = airings.first(where: { ($0.startDate ?? .distantPast) > now }) {
            return .laterToday(later)
        }
        if let predicted = WeeklyTemplate.nextPredicted(seriesID: seriesID, in: slots,
                                                        realChannels: Set(today.keys),
                                                        after: now) {
            return .usually(predicted.slot, next: predicted.start)
        }
        if let earlier = airings.last(where: { $0.isCatchUp(at: now) }) {
            return .earlierToday(earlier)
        }
        let known = channelSlugs.contains { today[$0] != nil } || !airings.isEmpty
        return known ? .notOnAgainToday : .unknown
    }
}

extension ShowAiring {
    /// The line under the show's title: *On now on P1*, *22:03 on P1*, *Usually Tuesdays
    /// 07:05*, *Earlier today · Listen*, *Not on again today*.
    ///
    /// Times and weekdays are the listener's own: a prediction is stored in Copenhagen time,
    /// but someone listening from abroad wants to know when it is on where they are.
    func caption(channelTitle: (String) -> String) -> String {
        switch self {
        case .onNow(let episode):
            let channel = channelTitle(episode.channel.slug)
            return String(localized: "On now on \(channel)")
        case .laterToday(let episode):
            let channel = channelTitle(episode.channel.slug)
            let time = episode.startDate?.formatted(date: .omitted, time: .shortened) ?? ""
            return String(localized: "\(time) on \(channel)")
        case .usually(_, let next):
            return Self.usuallyCaption(next)
        case .earlierToday:
            return String(localized: "Earlier today · Listen")
        case .notOnAgainToday:
            return String(localized: "Not on again today")
        case .unknown:
            return String(localized: "Checking the schedule")
        }
    }

    /// One key per weekday rather than a weekday name dropped into a sentence: Danish puts
    /// the plural weekday in lower case, and other languages decline it.
    private static func usuallyCaption(_ next: Date) -> String {
        let time = next.formatted(date: .omitted, time: .shortened)
        switch Calendar.current.component(.weekday, from: next) {
        case 1: return String(localized: "Usually Sundays \(time)")
        case 2: return String(localized: "Usually Mondays \(time)")
        case 3: return String(localized: "Usually Tuesdays \(time)")
        case 4: return String(localized: "Usually Wednesdays \(time)")
        case 5: return String(localized: "Usually Thursdays \(time)")
        case 6: return String(localized: "Usually Fridays \(time)")
        default: return String(localized: "Usually Saturdays \(time)")
        }
    }
}
