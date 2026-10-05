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
                        .padding(.horizontal, 2)
                        .padding(.vertical, 8)
                    }
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

        return Button {
            switch action {
            case .playLive(let channel), .showSchedule(let channel):
                serviceManager.playChannel(channel)
            case .playRecording(let episode):
                serviceManager.playOnDemand(episode)
            case .none:
                break
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                FavouriteShowArtwork(show: show, channel: channel)
                    .frame(width: metrics.width, height: metrics.height)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        StationCard.Caption(title: show.title, metrics: metrics)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius,
                                                style: .continuous))
                StationCard.Subtitle(text: caption, metrics: metrics)
            }
            .frame(width: metrics.width, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(show.title), \(caption)"))
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
