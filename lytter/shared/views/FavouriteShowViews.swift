//
//  FavouriteShowViews.swift
//  lytter
//

import SwiftUI

/// What choosing a favourite show does, decided once for every platform's shelf (F33).
enum FavouriteShowAction {
    /// It is on now: play the channel live.
    case playLive(DRChannel)
    /// It was on earlier today and can be listened back to.
    case playRecording(DREpisode)
    /// It is on later, or usually on: show the channel's schedule.
    case showSchedule(DRChannel)
    /// Nothing to offer: no channel it is known on is in the catalogue.
    case none

    init(airing: ShowAiring, show: FavouriteShow, serviceManager: DRServiceManager) {
        let channel = (airing.channelSlug ?? show.channelSlugs.first)
            .flatMap(serviceManager.channel(forSlug:))
        switch airing {
        case .onNow:
            self = channel.map(Self.playLive) ?? .none
        case .earlierToday(let episode):
            self = .playRecording(episode)
        case .laterToday, .usually, .notOnAgainToday, .unknown:
            self = channel.map(Self.showSchedule) ?? .none
        }
    }

    var accessibilityHint: LocalizedStringKey {
        switch self {
        case .playLive: "Plays the channel it is on"
        case .playRecording: "Plays the recording"
        case .showSchedule: "Shows the channel's schedule"
        case .none: ""
        }
    }
}

extension DRServiceManager {
    /// The caption line for `airing`, naming channels as the catalogue does.
    func caption(for airing: ShowAiring) -> String {
        airing.caption { slug in self.channel(forSlug: slug)?.qualifiedName ?? slug.uppercased() }
    }
}

/// A favourite show's card face: the tile its station has under Favourites — the station's
/// name across its colour, the show's picture showing through — with the show's title
/// beneath the name, where a station's tile has its programme.
///
/// Shows were the one card left with the old design, a picture with its title on glass
/// across the foot, beside station tiles that had moved on (#98, #101). Every platform's
/// shelf draws this, at the size its cards already were.
struct FavouriteShowTile: View {
    let show: FavouriteShow
    let channel: DRChannel?

    var body: some View {
        if let channel {
            StationNameTile(name: channel.name, stationKey: channel.stationKey,
                            details: [show.title],
                            artworkURL: show.imageURL.flatMap(URL.init(string:)))
        } else {
            // On no station in the catalogue: no station to name, so the show is the name.
            StationNameTile(name: show.title, stationKey: "")
        }
    }
}

/// "Add Show to Favourites" / "Remove Show from Favourites", for a programme in a schedule
/// or in the player (F33). Draws nothing for a programme DR files under no series.
///
/// Observes the preferences directly; through `DRServiceManager` it would not redraw.
struct FavouriteShowButton: View {
    let episode: DREpisode
    @ObservedObject var preferences: UserPreferencesService

    var body: some View {
        if let show = FavouriteShow(episode: episode) {
            let isFavourite = preferences.isFavouriteShow(show.seriesID)
            Button {
                preferences.toggleFavouriteShow(show)
            } label: {
                Label(isFavourite ? "Remove Show from Favourites" : "Add Show to Favourites",
                      systemImage: isFavourite ? "heart.slash" : "heart")
            }
        }
    }
}
