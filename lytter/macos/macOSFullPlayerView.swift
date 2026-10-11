//
//  macOSFullPlayerView.swift
//  lytter
//

import SwiftUI

#if os(macOS)
/// The full player on the Mac, opened from the mini player: the programme's artwork, what is
/// on, how far through it the broadcast is, and the transport.
///
/// The same pieces as the phone's player — `PlayerArtworkView`, `PlayerInfoView`, the
/// progress and the controls — laid out for a sheet of fixed size rather than a screen of
/// any height. `FullPlayerSheet` drew nothing here before, so the sheet opened empty.
///
/// No schedule and no sleep timer: their sheets are the phone's, and the Mac has neither yet.
/// The programme's description opens in a popover, the Mac's way of showing a little more,
/// beside AirPlay.
struct macOSFullPlayerView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingDescription = false

    /// The artwork's frame. `PlayerArtworkView` draws its square at four-fifths of it.
    private static let artworkSide: CGFloat = 340

    var body: some View {
        Group {
            if let channel = serviceManager.playingChannel {
                player(for: channel)
            } else {
                ContentUnavailableView("No Channel Playing",
                                       systemImage: "antenna.radiowaves.left.and.right")
            }
        }
        // Plain throughout: the shared controls are drawn as glyphs, and the Mac's default
        // style would put each in a push button's bezel — the play glyph bigger than its own.
        .buttonStyle(.plain)
        .frame(width: 420)
        .frame(minHeight: 560, idealHeight: 680)
        .toolbar {
            // Escape closes it too, as it closes any sheet on the Mac.
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func player(for channel: DRChannel) -> some View {
        let programme = serviceManager.getCurrentProgram(for: channel)
        return VStack(spacing: 0) {
            PlayerArtworkView(channel: channel, currentProgram: programme,
                              channelColor: channel.stationColor)
                .frame(width: Self.artworkSide, height: Self.artworkSide)

            VStack(spacing: 20) {
                // Only what stops audio: offline, or this stream failing.
                ConnectionBanner(serviceManager: serviceManager, playbackOnly: true)
                    .padding(.horizontal, 20)

                // The share control lives inside PlayerInfoView.
                PlayerInfoView(title: title(for: channel), subtitle: subtitle(for: channel),
                               channel: channel, serviceManager: serviceManager)

                Group {
                    if serviceManager.onDemandEpisode != nil {
                        OnDemandProgressView(
                            position: serviceManager.onDemandPosition,
                            duration: serviceManager.onDemandDuration,
                            onSeek: { serviceManager.seekOnDemand(to: $0) }
                        )
                    } else {
                        PlayerProgressView(programme: programme,
                                           secondsBehindLive: serviceManager.secondsBehindLive)
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer(minLength: 16)

            // Skip and Live only where the stream has a window to seek in, as on the phone.
            PlayerControlsView(
                isPlaying: serviceManager.isPlaying,
                showBackwardButton: serviceManager.canSeek,
                showForwardButton: serviceManager.canSeek,
                onBackwardTap: { serviceManager.skip(by: -AudioPlayerService.skipInterval) },
                onPlayPauseTap: { serviceManager.togglePlayback(for: channel) },
                onForwardTap: { serviceManager.skip(by: AudioPlayerService.skipInterval) },
                isForwardEnabled: serviceManager.isBehindLive,
                onLiveTap: serviceManager.canSeek ? { serviceManager.seekToLive() } : nil,
                isBehindLive: serviceManager.isBehindLive
            )
            // The glyphs are sized from the row's height, play at four-fifths of it. Live
            // goes under them, past the row's foot, so it is given the room there.
            .frame(height: 64)
            .padding(.vertical, serviceManager.canSeek ? 20 : 0)

            Spacer(minLength: 12)

            // Two of the phone's four actions: schedule and sleep timer have no sheets here.
            // Not `PlayerActionsView`, whose row is spaced for four and whose AirPlay is not
            // handed the player the Mac's picker routes.
            HStack(spacing: 56) {
                Button {
                    showingDescription = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .help("Programme information")
                .accessibilityLabel("Programme information")
                .popover(isPresented: $showingDescription, arrowEdge: .top) {
                    description(of: programme)
                }

                AirPlayButtonView(size: 24, tint: .secondaryLabel,
                                  player: serviceManager.routedPlayer)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    /// The programme's name, when it aired and what it is about.
    private func description(of programme: DREpisode?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = programme?.cleanTitle(), !title.isEmpty {
                Text(title)
                    .font(.headline)
            }
            if let start = programme?.startDate, let end = programme?.endDate {
                Text(verbatim: "\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
            Text(programme?.description ?? String(localized: "Live radio programming"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 320, alignment: .leading)
        .padding(16)
    }

    /// The phone's player's title: the station, and the programme too while a track plays,
    /// since the track then takes the line beneath.
    private func title(for channel: DRChannel) -> String {
        guard let track = serviceManager.currentTrack, serviceManager.isHeard(track) else {
            return channel.title
        }
        let programme = serviceManager.getCurrentProgram(for: channel)?.cleanTitle()
            ?? String(localized: "Live")
        return "\(channel.title) - \(programme)"
    }

    private func subtitle(for channel: DRChannel) -> String {
        if let track = serviceManager.currentTrack, serviceManager.isHeard(track) {
            return track.displayText
        }
        return serviceManager.getCurrentProgram(for: channel)?.cleanTitle()
            ?? String(localized: "Live")
    }
}
#endif
