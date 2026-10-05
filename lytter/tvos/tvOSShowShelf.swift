//
//  tvOSShowShelf.swift
//  lytter
//

import SwiftUI

#if os(tvOS)
/// Favourite shows on Home, under Favourites (F33) — the television's `ShowShelf`.
///
/// Every card is a button, so the row scrolls under the remote; `TVScrollingUITests` drives
/// it. Holding select offers the schedule and removal, as a station card offers pinning.
struct tvOSShowShelf: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var preferences: UserPreferencesService
    @ObservedObject var showSchedule: ShowScheduleService
    let onPlayLive: (DRChannel) -> Void
    let onPlayRecording: (DREpisode) -> Void
    /// As `tvOSChannelShelf`'s: lets Home place focus on a card.
    var focus: FocusState<String?>.Binding? = nil

    @State private var scheduleChannel: DRChannel?

    static let title = String(localized: "Shows")

    private var metrics: StationCardMetrics { .tvOS(.standard) }

    var body: some View {
        if !preferences.favouriteShows.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text(Self.title)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 60)

                TimelineView(.everyMinute) { context in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 40) {
                            ForEach(preferences.favouriteShows.shows) { show in
                                focusable(card(for: show, now: context.date), show: show)
                            }
                        }
                        .padding(.horizontal, 60)
                        // Room for the focused card's lift, as on the channel shelves.
                        .padding(.vertical, 30)
                    }
                }
            }
            .sheet(item: $scheduleChannel) { channel in
                tvOSChannelScheduleSheet(channel: channel, serviceManager: serviceManager)
            }
        }
    }

    @ViewBuilder
    private func focusable(_ card: some View, show: FavouriteShow) -> some View {
        if let focus {
            card.focused(focus, equals: Self.focusKey(show))
        } else {
            card
        }
    }

    static func focusKey(_ show: FavouriteShow) -> String { "\(title)/\(show.seriesID)" }

    private func card(for show: FavouriteShow, now: Date) -> some View {
        let airing = showSchedule.airing(for: show, now: now)
        let action = FavouriteShowAction(airing: airing, show: show, serviceManager: serviceManager)
        let caption = serviceManager.caption(for: airing)
        let channel = (airing.channelSlug ?? show.channelSlugs.first)
            .flatMap(serviceManager.channel(forSlug:))

        return VStack(alignment: .leading, spacing: 24) {
            Button {
                perform(action)
            } label: {
                FavouriteShowArtwork(show: show, channel: channel)
                    .frame(width: metrics.width, height: metrics.height)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        StationCard.Caption(title: show.title, metrics: metrics)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "\(show.title), \(caption)"))
            }
            .buttonStyle(.card)
            .accessibilityHint(action.accessibilityHint)
            // On the button, the focusable view, or hold-select does nothing.
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

            StationCard.Subtitle(text: caption, metrics: metrics)
        }
        .frame(width: metrics.width, alignment: .leading)
    }

    private func perform(_ action: FavouriteShowAction) {
        switch action {
        case .playLive(let channel): onPlayLive(channel)
        case .playRecording(let episode): onPlayRecording(episode)
        case .showSchedule(let channel): scheduleChannel = channel
        case .none: break
        }
    }
}
#endif
