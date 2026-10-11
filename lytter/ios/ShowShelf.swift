//
//  ShowShelf.swift
//  lytter
//

import SwiftUI

#if os(iOS) || os(visionOS)
/// Favourite shows on Home, under Favourites (F33): each show as its station's tile with the
/// show's title on it (`FavouriteShowTile`), and one line saying when it is next on.
///
/// Observes the preferences and the show schedule directly; through `DRServiceManager`
/// neither would redraw it (see AGENTS.md). Redrawn every minute as well, since "on now"
/// and "later today" go stale on their own.
struct ShowShelf: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var preferences: UserPreferencesService
    @ObservedObject var showSchedule: ShowScheduleService

    @State private var scheduleChannel: DRChannel?

    private var metrics: StationCardMetrics { .iOS(.standard) }

    var body: some View {
        if !preferences.favouriteShows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Shows")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 16)

                TimelineView(.everyMinute) { context in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 14) {
                            ForEach(preferences.favouriteShows.shows) { show in
                                card(for: show, now: context.date)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }
            }
            .sheet(item: $scheduleChannel) { channel in
                iOSChannelScheduleSheet(channel: channel, serviceManager: serviceManager)
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
            perform(action)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                FavouriteShowTile(show: show, channel: channel)
                    .frame(width: metrics.width, height: metrics.height)
                    .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius,
                                                style: .continuous))
                    .shadow(color: .black.opacity(0.14), radius: 10, y: 2)

                StationCard.Subtitle(text: airing.timeCaption, metrics: metrics)
                    // Centred under the tile, which centres its own text. A time is short, and
                    // the longest line ("Usually Wednesdays 22.03") still fits.
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .frame(width: metrics.width, alignment: .leading)
        }
        .buttonStyle(.plain)
        .cardHoverEffect(cornerRadius: metrics.cornerRadius)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(show.title), \(caption)"))
        .accessibilityHint(action.accessibilityHint)
        .contextMenu {
            if let channel {
                Button {
                    scheduleChannel = channel
                } label: {
                    Label("Show Schedule", systemImage: "list.bullet")
                }
            }
            Button(role: .destructive) {
                preferences.removeFavouriteShow(show.seriesID)
            } label: {
                Label("Remove Show from Favourites", systemImage: "heart.slash")
            }
        }
    }

    private func perform(_ action: FavouriteShowAction) {
        switch action {
        case .playLive(let channel): serviceManager.playChannel(channel)
        case .playRecording(let episode): serviceManager.playOnDemand(episode)
        case .showSchedule(let channel): scheduleChannel = channel
        case .none: break
        }
    }
}
#endif
