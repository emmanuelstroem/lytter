//
//  FavouriteStations.swift
//  WidgetShared
//

import Foundation

/// The stations the listener has pinned, as the Favourites widget draws them (F18).
///
/// Written by the app beside `NowPlayingSnapshot` whenever the favourites or the catalogue
/// change; which of them is playing comes from the Now Playing snapshot, so play/pause does
/// not rewrite this one.
nonisolated struct FavouriteStations: Codable, Equatable, Sendable {
    static let schemaVersion = 2

    /// The most a widget draws: the large one's eight.
    static let limit = 8

    struct Station: Codable, Equatable, Sendable, Identifiable {
        let channelID: String
        let broadcaster: String
        /// "P4 - Fyn": a favourite is one particular district.
        let channelName: String
        let stationName: String
        /// "København", for a channel that is a district.
        let district: String?
        let stationKey: String
        /// What is on now, if the schedule says, and until when.
        let programme: String?
        let programmeEnd: Date?

        var id: String { channelID }

        /// The programme, while it is still on at `date`, and only when it says more than
        /// the channel's name.
        func subtitle(at date: Date) -> String? {
            guard let programme, !programme.isEmpty else { return nil }
            if let programmeEnd, date >= programmeEnd { return nil }
            let repeats = [channelName, stationName].contains {
                $0.compare(programme, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }
            return repeats ? nil : programme
        }
    }

    let version: Int
    /// In the order they were pinned, as the app lists them.
    let stations: [Station]

    init(stations: [Station]) {
        self.version = Self.schemaVersion
        self.stations = stations
    }

    /// When a programme ends and its line should go, after `date`.
    func changes(after date: Date) -> [Date] {
        Array(Set(stations.compactMap(\.programmeEnd).filter { $0 > date })).sorted()
    }
}

extension NowPlayingStore {
    static let favouritesFileName = "favourite_stations.json"
    static let favouritesKind = "com.eopio.lytter.favourites"

    private var favouritesURL: URL? { directory?.appendingPathComponent(Self.favouritesFileName) }

    func loadFavourites() -> FavouriteStations? {
        guard let url = favouritesURL, let data = try? Data(contentsOf: url),
              let favourites = try? JSONDecoder().decode(FavouriteStations.self, from: data),
              favourites.version == FavouriteStations.schemaVersion else { return nil }
        return favourites
    }

    func saveFavourites(_ favourites: FavouriteStations) {
        guard let url = favouritesURL, let data = try? JSONEncoder().encode(favourites) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
