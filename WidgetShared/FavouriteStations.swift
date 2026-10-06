//
//  FavouriteStations.swift
//  WidgetShared
//

import Foundation

/// The stations the listener has pinned, as the Favourites widget draws them (F18).
///
/// Written by the app beside `NowPlayingSnapshot` whenever the favourites or the channels
/// change; which of them is playing comes from the Now Playing snapshot, so play/pause does
/// not rewrite this one.
nonisolated struct FavouriteStations: Codable, Equatable, Sendable {
    static let schemaVersion = 3

    /// The most a widget draws: the large one's three rows of four.
    static let limit = 12

    struct Station: Codable, Equatable, Sendable, Identifiable {
        let channelID: String
        let broadcaster: String
        /// "P4 - København": a favourite is one particular district. For VoiceOver; the tile
        /// itself is the station's logo.
        let channelName: String
        let stationName: String
        /// "København", for a channel that is a district: the one word on its tile, since
        /// every P4 district shares the P4 logo.
        let district: String?
        let stationKey: String

        var id: String { channelID }
    }

    let version: Int
    /// In the order they were pinned, as the app lists them.
    let stations: [Station]

    init(stations: [Station]) {
        self.version = Self.schemaVersion
        self.stations = stations
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
