//
//  ChannelDirectory.swift
//  lytter
//

import Foundation

/// What DR says each channel is: which station it belongs to, and which district, if any.
///
/// The app lists channels from `schedules/all/now`, whose channel objects carry only a
/// title and a slug. Station and district used to be read from the title by splitting it
/// on the first space, which is right for every title DR broadcasts today and wrong for
/// the first national channel with a two-word name — DR's own directory already lists
/// one, "P7 MIX". `/channels` states the answer outright: each station lists its districts,
/// and each district names its parent and its district.
///
/// Keyed by channel slug, which is the one identifier both endpoints share.
struct ChannelDirectory: Equatable, Sendable {

    struct Entry: Equatable, Sendable {
        let stationSlug: String
        let stationTitle: String
        let districtName: String?
    }

    private(set) var entries: [String: Entry]

    init(entries: [String: Entry] = [:]) {
        self.entries = entries
    }

    var isEmpty: Bool { entries.isEmpty }

    /// Builds the directory from `/channels`.
    ///
    /// A station is its own entry, with no district. Each of its districts is an entry
    /// pointing back at it, named with DR's `districtName` — or, should DR ever leave that
    /// out, with whatever its title has after the station's.
    init(stations: [Station]) {
        var entries: [String: Entry] = [:]
        for station in stations {
            entries[station.slug] = Entry(stationSlug: station.slug,
                                          stationTitle: station.title,
                                          districtName: nil)
            for district in station.districts ?? [] {
                let name = district.districtName
                    ?? district.title.flatMap { Self.remainder(of: $0, after: station.title) }
                entries[district.slug] = Entry(stationSlug: district.parentChannelSlug ?? station.slug,
                                               stationTitle: station.title,
                                               districtName: name)
            }
        }
        self.entries = entries
    }

    /// Recovers a directory from channels it was applied to before.
    ///
    /// The directory is not stored on its own, but every channel it was applied to carries
    /// its entry through the disk cache. So when `/channels` cannot be reached, the last
    /// answer is still known rather than the app falling back to reading titles.
    init(learningFrom channels: [DRChannel]) {
        var entries: [String: Entry] = [:]
        for channel in channels {
            guard let stationSlug = channel.stationSlug,
                  let stationTitle = channel.stationTitle else { continue }
            entries[channel.slug] = Entry(stationSlug: stationSlug,
                                          stationTitle: stationTitle,
                                          districtName: channel.districtName)
        }
        self.entries = entries
    }

    /// The channel, with what the directory knows about it attached. A channel the
    /// directory does not list comes back unchanged, and keeps reading its title.
    func apply(to channel: DRChannel) -> DRChannel {
        guard let entry = entries[channel.slug] else { return channel }
        var channel = channel
        channel.stationSlug = entry.stationSlug
        channel.stationTitle = entry.stationTitle
        channel.districtName = entry.districtName
        return channel
    }

    private static func remainder(of title: String, after stationTitle: String) -> String? {
        guard title.hasPrefix(stationTitle) else { return nil }
        let rest = title.dropFirst(stationTitle.count).trimmingCharacters(in: .whitespaces)
        return rest.isEmpty ? nil : rest
    }
}

// MARK: - `/channels` as DR sends it

extension ChannelDirectory {

    /// One station, as listed by `/channels`. Only the fields the directory needs.
    struct Station: Decodable, Sendable {
        let slug: String
        let title: String
        let districts: [ListedDistrict]?
    }

    struct ListedDistrict: Decodable, Sendable {
        let slug: String
        let title: String?
        let districtName: String?
        let parentChannelSlug: String?
    }
}
