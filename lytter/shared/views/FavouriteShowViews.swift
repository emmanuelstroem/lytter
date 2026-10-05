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

/// A show's artwork, or the colour of the channel it is on when there is none, or when
/// Show Images is off.
struct FavouriteShowArtwork: View {
    let show: FavouriteShow
    let channel: DRChannel?

    var body: some View {
        CachedAsyncImage(url: show.imageURL.flatMap(URL.init(string:)),
                         maxPixelSize: ImageCacheService.thumbnailMaxPixelSize) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            // The caption names the show; the station's name here would contradict it.
            StationArtworkPlaceholder(channel: channel, showsName: false)
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
