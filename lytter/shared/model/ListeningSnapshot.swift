//
//  ListeningSnapshot.swift
//  lytter
//

import Foundation

// What the widgets are told (F18), decided from the app's own model.
// `ListeningSurfaces` only gathers the inputs and hands the result on; the decisions are
// here, where they can be tested without WidgetKit.

extension NowPlayingSnapshot {
    /// The most programmes handed over: the one being heard and the rest of the evening.
    /// Each is a WidgetKit entry boundary, and the app writes again long before these run out.
    static let programmeLimit = 6

    /// A snapshot of `channel` playing `programme`, followed by whatever of `upcoming`
    /// comes after it.
    ///
    /// `upcoming` is the channel's schedule snapshot, which starts with the programme
    /// *before* the one on air; anything not after `programme` is dropped. A recording has
    /// no "after": it is one programme.
    ///
    /// With no `programme` — the catalogue still lists the one that has just ended, until its
    /// next refresh some minutes later — the one `upcoming` has on air is used instead, so a
    /// boundary does not empty the widget.
    static func make(channel: DRChannel, programme: DREpisode?, upcoming: [DREpisode],
                     isPlaying: Bool, isOnDemand: Bool,
                     secondsBehindLive: TimeInterval, now: Date) -> NowPlayingSnapshot {
        let heard = now.addingTimeInterval(-secondsBehindLive)
        let programme = programme
            ?? (isOnDemand ? nil : upcoming.first { episode in
                // Half-open, as the widget reads it: at a boundary, the one starting.
                guard let start = episode.startDate, let end = episode.endDate else { return false }
                return start <= heard && heard < end
            })
        var programmes: [Programme] = []
        if let programme {
            programmes.append(Programme(programme))
            if !isOnDemand, let end = programme.endDate {
                programmes += upcoming
                    .filter { $0.id != programme.id && ($0.startDate ?? .distantPast) >= end }
                    .sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
                    .prefix(programmeLimit - 1)
                    .map(Programme.init)
            }
        }


        return NowPlayingSnapshot(
            channelID: channel.id,
            broadcaster: Broadcaster.supplying(channel).name,
            channelName: channel.qualifiedName,
            stationName: channel.name,
            district: channel.district,
            stationKey: channel.stationKey,
            isPlaying: isPlaying,
            isOnDemand: isOnDemand,
            secondsBehindLive: isOnDemand ? 0 : secondsBehindLive,
            programmes: programmes,
            savedAt: now)
    }

    /// The same snapshot, paused. What the widget keeps once playback stops altogether, so
    /// it still names the station its button would resume. Dated `now` if it was playing,
    /// since that is when it stopped; left as it was if it had already been paused.
    func paused(at now: Date) -> NowPlayingSnapshot {
        NowPlayingSnapshot(channelID: channelID, broadcaster: broadcaster, channelName: channelName,
                           stationName: stationName, district: district, stationKey: stationKey,
                           isPlaying: false, isOnDemand: isOnDemand,
                           secondsBehindLive: secondsBehindLive, programmes: programmes, savedAt: isPlaying ? now : savedAt)
    }

    /// Whether `other` says the same thing, whenever it was written. Writing a snapshot
    /// that differs only in its date would redraw every widget for nothing — and, paused,
    /// would move the moment the widget thinks is being heard.
    func says(theSameAs other: NowPlayingSnapshot?) -> Bool {
        guard let other else { return false }
        return channelID == other.channelID && channelName == other.channelName
            && broadcaster == other.broadcaster
            && isPlaying == other.isPlaying && isOnDemand == other.isOnDemand
            && abs(secondsBehindLive - other.secondsBehindLive) < 5
            && programmes == other.programmes
    }
}

private extension NowPlayingSnapshot.Programme {
    init(_ episode: DREpisode) {
        self.init(title: episode.programmeName, start: episode.startDate, end: episode.endDate)
    }
}

extension FavouriteStations {
    /// The pinned channels, in pinned order.
    ///
    /// Channels the catalogue does not have are left out, as the app's own Favourites shelf
    /// leaves them out (`Favourites.resolve`); past `limit`, the rest are for the app.
    static func make(favourites: Favourites, channels: [DRChannel]) -> FavouriteStations {
        let stations = favourites.resolve(in: channels).prefix(limit).map { channel in
            Station(channelID: channel.id,
                    broadcaster: Broadcaster.supplying(channel).name,
                    channelName: channel.qualifiedName,
                    stationName: channel.name,
                    district: channel.district,
                    stationKey: channel.stationKey)
        }
        return FavouriteStations(stations: Array(stations))
    }
}
