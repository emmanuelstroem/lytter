//
//  GroupedChannel.swift
//  lytter
//

import Foundation

/// One station, with its regional variants folded in.
///
/// P4 and P5 are broadcast as ten district channels each; everywhere but the district
/// picker they should read as a single station.
///
/// Shared rather than per-platform. This is domain, not presentation: tvOS had its own
/// copy of the grouping and macOS would have needed a third. A station is a station
/// whatever is drawing it.
struct GroupedChannel: Identifiable {
    let id: String
    let name: String
    let channels: [DRChannel]

    init(channels: [DRChannel]) {
        // Sorted, because the channels arrive from Dictionary(grouping:) — whose value
        // order is not defined — and both `id` and `name` are taken from the first one.
        // Unsorted, a station's identity could differ between launches.
        let ordered = channels.sorted { $0.displayName < $1.displayName }
        self.channels = ordered
        self.name = ordered.first?.name ?? ""
        self.id = ordered.first?.id ?? ""
    }

    var hasMultipleDistricts: Bool {
        return channels.count > 1
    }

    /// What to call this on a card.
    ///
    /// A group of one is a specific channel, so if it has a district, name it: a shelf of
    /// favourites otherwise shows several cards all captioned "P4" with no way to tell
    /// København from Bornholm. A group of ten stands for the station as a whole, and is
    /// named for the station.
    var displayTitle: String {
        guard !hasMultipleDistricts, let only = channels.first else { return name }
        return only.qualifiedName
    }

    var districts: [String] {
        return channels.compactMap { $0.district }.uniqued()
    }

    /// The channel serving `district`, if this station broadcasts one for it.
    ///
    /// Matched on the district's identifier rather than its name, so a region chosen on
    /// P4 finds its counterpart on P5 — which is the point of `District` having an id at
    /// all.
    func channel(in district: District) -> DRChannel? {
        channels.first { $0.districtID == district.id }
    }

    /// Every variant, with the listener's region first and the rest in the usual order.
    ///
    /// What the district picker lists. Choosing a station always asks which district, so
    /// that a listener away from home can pick another one; putting their own first keeps
    /// the usual choice a single tap.
    func channels(regionFirst region: District?) -> [DRChannel] {
        guard let region, let mine = channel(in: region) else { return channels }
        return [mine] + channels.filter { $0.id != mine.id }
    }

    /// The single channel this station stands for, where it stands for only one.
    var soleChannel: DRChannel? {
        hasMultipleDistricts ? nil : channels.first
    }

    /// One channel to represent the station in a flat list.
    ///
    /// The variant without a district when there is one — a list of stations wants "P1",
    /// not "P1 something" — and otherwise the first, which `init` has already ordered.
    var representative: DRChannel? {
        channels.first { $0.district == nil } ?? channels.first
    }
}

extension GroupedChannel {
    /// Groups a flat channel list into one entry per station, ordered by name.
    ///
    /// Home, Radio and Search each had their own copy of this; they now share one.
    static func grouped(from channels: [DRChannel]) -> [GroupedChannel] {
        // By station identity, not by name: DR's own station slug once the directory is
        // known, so a two-word national channel is a station of its own rather than a
        // district of whichever station shares its first word.
        Dictionary(grouping: channels) { $0.stationKey }
            .values
            .map { GroupedChannel(channels: $0) }
            // As a reader sorts: P2 before P10, and "radio Soft" beside "Radio Alfa".
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Whether this station answers a search.
    ///
    /// Matches the station name, any variant's display name or slug, and what is on air
    /// — so "orientering" finds P1 while that programme is running, which is the thing a
    /// listener is most likely to be looking for.
    func matches(_ query: String, nowPlaying: (DRChannel) -> String? = { _ in nil }) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        if name.localizedCaseInsensitiveContains(trimmed) { return true }

        return channels.contains { channel in
            channel.displayName.localizedCaseInsensitiveContains(trimmed)
                || channel.slug.localizedCaseInsensitiveContains(trimmed)
                || (nowPlaying(channel)?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    /// What a search lists for this station: the station, the districts that matched, or
    /// nothing.
    ///
    /// The whole station when its own name matches — "P4" means P4. Otherwise only the
    /// variants that answered, so "Fyn" lists P4 Fyn and P5 Fyn as channels to play rather
    /// than P4 and P5 as stations to pick a district from all over again.
    func searchResult(for query: String,
                      nowPlaying: (DRChannel) -> String? = { _ in nil }) -> GroupedChannel? {
        guard matches(query, nowPlaying: nowPlaying) else { return nil }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasMultipleDistricts, !trimmed.isEmpty,
              !name.localizedCaseInsensitiveContains(trimmed) else { return self }

        let hits = channels.filter { GroupedChannel(channels: [$0]).matches(trimmed, nowPlaying: nowPlaying) }
        return hits.count == channels.count ? self : GroupedChannel(channels: hits)
    }
}
