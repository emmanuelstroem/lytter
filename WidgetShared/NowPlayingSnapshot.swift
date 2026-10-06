//
//  NowPlayingSnapshot.swift
//  WidgetShared
//

import Foundation

/// What the widgets and the Control Centre control show (F18).
///
/// The app writes it into the app group whenever the station, the programme or play/pause
/// changes; the widget extension only ever reads it. The extension never asks
/// DR for anything: the app already knows all of this, and a second client would drift —
/// the Top Shelf's copy of the network layer is the warning (see `TopShelfNetworkService`).
///
/// Compiled into the app and the widget extension both, from `WidgetShared/`. Plain values
/// only, so neither side needs the other's model types.
nonisolated struct NowPlayingSnapshot: Codable, Equatable, Sendable {
    /// Bumped when a field changes meaning. A snapshot of another version is ignored, and
    /// the widget shows its empty state until the app writes again.
    static let schemaVersion = 3

    /// One broadcast, as the widgets need it.
    struct Programme: Codable, Equatable, Sendable {
        let title: String
        let start: Date?
        let end: Date?

        /// Whether `date` falls within it. One with either end missing is never "on":
        /// it cannot be placed.
        func isOn(at date: Date) -> Bool {
            guard let start, let end else { return false }
            return date >= start && date < end
        }

        /// How far through it `date` falls, 0 to 1; nil without both ends.
        func progress(at date: Date) -> Double? {
            guard let start, let end else { return nil }
            let total = end.timeIntervalSince(start)
            guard total > 0 else { return nil }
            return min(max(date.timeIntervalSince(start) / total, 0), 1)
        }
    }

    let version: Int
    /// The channel's id, for the link back into the app.
    let channelID: String
    /// Who broadcasts the channel: "DR".
    let broadcaster: String
    /// "P4 - Fyn", or "P3": the channel the listener chose, district and all.
    let channelName: String
    /// "P4": what a placeholder prints, and what picks its colour.
    let stationName: String
    /// "København" for P4 København; nil for a channel with no district. The widgets set it
    /// beside `stationName` rather than print `channelName`, which does not fit.
    let district: String?
    /// What `StationPalette` keys a station it does not know by.
    let stationKey: String
    let isPlaying: Bool
    /// A recording (F16) rather than the live stream. It has no "next".
    let isOnDemand: Bool
    /// How far behind live the listener was when this was written; 0 at live.
    let secondsBehindLive: TimeInterval
    /// The programme being heard first, then those after it in broadcast order.
    let programmes: [Programme]
    let savedAt: Date

    init(channelID: String, broadcaster: String, channelName: String, stationName: String,
         district: String? = nil, stationKey: String,
         isPlaying: Bool, isOnDemand: Bool = false, secondsBehindLive: TimeInterval = 0,
         programmes: [Programme], savedAt: Date) {
        self.version = Self.schemaVersion
        self.channelID = channelID
        self.broadcaster = broadcaster
        self.channelName = channelName
        self.stationName = stationName
        self.district = district
        self.stationKey = stationKey
        self.isPlaying = isPlaying
        self.isOnDemand = isOnDemand
        self.secondsBehindLive = secondsBehindLive
        self.programmes = programmes
        self.savedAt = savedAt
    }

    /// The moment being heard when the clock reads `date`.
    ///
    /// Behind live, that is earlier than the clock. Paused, it stays where it stopped:
    /// resuming carries on from there, so that is the programme the listener is in.
    func heardDate(at date: Date) -> Date {
        (isPlaying ? date : min(date, savedAt)).addingTimeInterval(-secondsBehindLive)
    }

    /// The programme to show at `date`.
    ///
    /// The one being heard then, if the schedule says. One whose times DR did not give is
    /// shown if it comes first, as the app does: it cannot be judged either way. Once every
    /// known programme has ended, none — the widget names the station and nothing it
    /// cannot vouch for. A recording is its one programme wherever the clock is.
    func programme(at date: Date) -> Programme? {
        if isOnDemand { return programmes.first }
        let heard = heardDate(at: date)
        if let on = programmes.first(where: { $0.isOn(at: heard) }) { return on }
        guard let first = programmes.first else { return nil }
        if first.start == nil || first.end == nil { return first }
        return nil
    }

    /// The line under the channel's name at `date`: the programme, unless there is none or
    /// its title only says the channel's name again — "P2" under "P2".
    func subtitle(at date: Date) -> String? {
        guard let title = programme(at: date)?.title.trimmingCharacters(in: .whitespaces),
              !title.isEmpty else { return nil }
        let repeats = [channelName, stationName].contains {
            $0.compare(title, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        return repeats ? nil : title
    }

    /// The programme after the one shown at `date`, if the app knew of one.
    func next(after date: Date) -> Programme? {
        guard !isOnDemand, let current = programme(at: date),
              let index = programmes.firstIndex(of: current),
              programmes.indices.contains(index + 1) else { return nil }
        return programmes[index + 1]
    }

    /// When `programme` runs by the clock, for a progress bar that fills on its own. Nil
    /// without both ends, or while paused, when nothing should move.
    func clockInterval(of programme: Programme) -> ClosedRange<Date>? {
        guard isPlaying, !isOnDemand, let start = programme.start, let end = programme.end,
              end > start else { return nil }
        return start.addingTimeInterval(secondsBehindLive)...end.addingTimeInterval(secondsBehindLive)
    }

    /// When what the widget shows next changes on its own: a programme starting or ending.
    /// Sorted, after `date`, at most `limit`.
    ///
    /// WidgetKit is handed one entry for each, so the widget moves on to the next
    /// programme at its start without the app having to run.
    func changes(after date: Date, limit: Int = 24) -> [Date] {
        var dates = Set<Date>()
        // Programme times are broadcast times; heard behind live, each comes that much later.
        // Paused, nothing moves on.
        if !isOnDemand, isPlaying {
            for programme in programmes {
                for edge in [programme.start, programme.end].compactMap({ $0 }) {
                    let clock = edge.addingTimeInterval(secondsBehindLive)
                    if clock > date { dates.insert(clock) }
                }
            }
        }
        return Array(dates.sorted().prefix(limit))
    }
}
