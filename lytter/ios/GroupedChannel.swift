//
//  GroupedChannel.swift
//  lytter
//

import SwiftUI

#if os(iOS)
/// One station, with its regional variants folded in.
///
/// P4 and P5 are broadcast as ten district channels each; everywhere but the district
/// picker they should read as a single station.
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

    var districts: [String] {
        return channels.compactMap { $0.district }.uniqued()
    }
}

extension GroupedChannel {
    /// Groups a flat channel list into one entry per station, ordered by name.
    ///
    /// Home, Radio and Search each had their own copy of this; they now share one.
    static func grouped(from channels: [DRChannel]) -> [GroupedChannel] {
        Dictionary(grouping: channels) { $0.name }
            .values
            .map { GroupedChannel(channels: $0) }
            .sorted { $0.name < $1.name }
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
}
#endif
