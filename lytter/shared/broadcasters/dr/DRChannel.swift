//
//  DRChannel.swift
//  lytter
//

import Foundation

// MARK: - Channel Models
nonisolated struct DRChannel: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let slug: String
    let type: String
    let presentationUrl: String?

    // What DR's channel directory says this channel is. The schedule endpoint the app
    // lists channels from sends none of it, so these stay nil until a `ChannelDirectory`
    // has been applied, and are then carried through the disk cache with the channel.

    /// The station this channel belongs to: "p4" for P4 København, the channel's own slug
    /// for a national channel such as P1.
    var stationSlug: String? = nil

    /// The station's own title: "P4" for P4 København.
    var stationTitle: String? = nil

    /// DR's name for the district, for a channel that is one.
    var districtName: String? = nil

    /// The `Broadcaster` that supplies this channel, set by its source. Nil is DR: DR's
    /// JSON has no such field, and nor does a channel cached before there was a second.
    var broadcasterID: String? = nil

    var displayName: String { title }

    /// The station's name: "P4" for P4 København, "P1" for P1.
    ///
    /// Taken from DR's directory where it has been applied. Otherwise read from the title,
    /// which is the fallback and nothing more: it splits on the first space, so a national
    /// channel with a two-word title — DR's directory has one, "P7 MIX" — would be read as
    /// station "P7" with a district called "MIX".
    var name: String {
        stationTitle ?? titleParts.station
    }

    /// The district, for a channel that is one.
    ///
    /// Once the directory has been applied, only what DR calls a district is one. Before
    /// that, whatever follows the first space in the title.
    var district: String? {
        stationSlug != nil ? districtName : titleParts.district
    }

    /// What identifies the station when channels are grouped into stations.
    ///
    /// DR's own station slug where the directory has been applied. Otherwise the name read
    /// from the title, lowercased so that a channel the directory does not list still
    /// lands beside its siblings rather than in a group of its own.
    var stationKey: String {
        stationSlug ?? name.lowercased()
    }

    private var titleParts: (station: String, district: String?) {
        let components = title.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        let station = components.first.map(String.init) ?? title
        return (station, components.count > 1 ? String(components[1]) : nil)
    }

    /// The name including the district, where there is one: "P4 - København".
    ///
    /// Needed wherever a card stands for one particular channel rather than for a station.
    /// A pinned favourite is a specific district, and "P4" alone does not say which of the
    /// ten it is — all ten would caption themselves identically.
    ///
    /// Not localised: a separator, not a phrase.
    var qualifiedName: String {
        guard let district else { return name }
        return "\(name) - \(district)"
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DRChannel, rhs: DRChannel) -> Bool {
        return lhs.id == rhs.id
    }
}
