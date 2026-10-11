//
//  macOSShowShelf.swift
//  lytter
//

import SwiftUI

#if os(macOS)
/// Favourite shows on Home, under Favourites (F33) — the Mac's `ShowShelf`.
///
/// The Mac has no schedule sheet, so a show that is not on now plays the channel it is on
/// instead: the nearest thing to "take me to it" there is here.
struct macOSShowShelf: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var preferences: UserPreferencesService
    @ObservedObject var showSchedule: ShowScheduleService

    private var metrics: StationCardMetrics { .macOS(.standard) }

    var body: some View {
        if !preferences.favouriteShows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Shows")
                    .font(.title2.weight(.bold))
                TimelineView(.everyMinute) { context in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 20) {
                            ForEach(preferences.favouriteShows.shows) { show in
                                card(for: show, now: context.date)
                            }
                        }
                        // As Home's other shelves, so the rows line up: no shadow here, but
                        // the focus ring stands outside the tile, and the scroll view clips.
                        .padding(macOSStationCard.shadowRoom)
                    }
                    .padding(macOSStationCard.shadowRoomReturned)
                }
            }
        }
    }

    private func card(for show: FavouriteShow, now: Date) -> some View {
        let airing = showSchedule.airing(for: show, now: now)
        let action = FavouriteShowAction(airing: airing, show: show, serviceManager: serviceManager)
        let caption = serviceManager.caption(for: airing)
        let channel = (airing.channelSlug ?? show.channelSlugs.first)
            .flatMap(serviceManager.channel(forSlug:))

        let tile = RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
        return VStack(alignment: .leading, spacing: 6) {
            // The tile alone is the button, as on a station's card, so the keyboard's focus
            // ring goes round the tile; round the time beneath as well, it stood clear of
            // the tile's foot.
            Button {
                switch action {
                case .playLive(let channel), .showSchedule(let channel):
                    serviceManager.playChannel(channel)
                case .playRecording(let episode):
                    serviceManager.playOnDemand(episode)
                case .none:
                    break
                }
            } label: {
                FavouriteShowTile(show: show, channel: channel)
                    .frame(width: metrics.width, height: metrics.height)
                    .clipShape(tile)
            }
            .buttonStyle(.plain)
            .contentShape(.focusEffect, tile)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "\(show.title), \(caption)"))

            StationCard.Subtitle(text: airing.timeCaption, metrics: metrics)
                // Centred under the tile, which centres its own text. A time is short, and
                // the longest line ("Usually Wednesdays 22.03") still fits.
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                // Read as part of the button's label.
                .accessibilityHidden(true)
        }
        .frame(width: metrics.width, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) {
                preferences.removeFavouriteShow(show.seriesID)
            } label: {
                Label("Remove Show from Favourites", systemImage: "heart.slash")
            }
        }
    }
}
#endif
