//
//  macOSMiniPlayer.swift
//  lytter
//

import SwiftUI

#if os(macOS)
/// What is playing, in a capsule floating over the foot of the detail pane: the iPad's mini
/// player, as Music draws it there, with the page scrolling on beneath it. Clicking the
/// station opens the full player.
///
/// It was a bar docked full-width along the window's foot, Music's "LCD" on the Mac. The
/// capsule is the same player on every device Lytter runs on, and it leaves the sidebar
/// its whole height.
///
/// The station's picture is round. The capsule's ends have a radius of half its height, and
/// the picture is inset `inset` from them: that radius less the inset is the picture's own
/// half width, so a circle is the curve that keeps an even gap round the end.
struct macOSMiniPlayer: View {
    @ObservedObject var serviceManager: DRServiceManager
    /// Observed itself rather than through the service manager, which does not republish
    /// it: the last-played station has to redraw the capsule when it changes.
    @ObservedObject var preferences: UserPreferencesService
    @ObservedObject var selectionState: SelectionState

    private static let artworkSide: CGFloat = 36
    private static let inset: CGFloat = 8

    /// The station shown: the one playing, or else the one played last, dimmed, which Play
    /// starts again — as the phone's mini player does.
    private var channel: DRChannel? {
        serviceManager.playingChannel
            ?? preferences.findLastPlayedChannel(in: serviceManager.availableChannels)
    }

    private var isPlayingChannel: Bool { serviceManager.playingChannel != nil }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                selectionState.isShowingFullPlayer = true
            } label: {
                HStack(spacing: 10) {
                    artwork
                    info
                }
                .contentShape(Rectangle())
            }
            .disabled(!isPlayingChannel)
            .help("Open the player")
            .accessibilityHint("Opens the player")
            .accessibilityIdentifier("miniPlayer")

            Spacer(minLength: 8)

            playPause
            // Share offers SharePlay in its menu, the way Music does.
            share
            AirPlayButtonView(size: 20, tint: .secondaryLabel,
                              player: serviceManager.routedPlayer)
                .frame(width: Self.artworkSide, height: Self.artworkSide)
                .opacity(isPlayingChannel ? 1 : 0.3)
        }
        .buttonStyle(.plain)
        .padding(Self.inset)
        .frame(maxWidth: 560)
        .modifier(MiniPlayerGlass())
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var artwork: some View {
        Group {
            if let channel {
                CachedAsyncImage(url: serviceManager.artworkURL(for: channel),
                                 maxPixelSize: ImageCacheService.thumbnailMaxPixelSize) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    StationArtworkPlaceholder(channel: channel)
                }
                .opacity(isPlayingChannel ? 1 : 0.7)
            } else {
                Color(nsColor: .tertiarySystemFill)
                    .overlay {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .foregroundStyle(Color.secondary)
                    }
            }
        }
        .frame(width: Self.artworkSide, height: Self.artworkSide)
        .clipShape(Circle())
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let channel {
                Text(channel.qualifiedName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary)
                // A problem that stops audio takes the programme's line: the player is the
                // one place on the Mac that is always in view.
                if isPlayingChannel, let problem = serviceManager.connectionProblem,
                   problem.affectsPlayback {
                    Label(problem.title, systemImage: problem.systemImage)
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                } else {
                    Text(serviceManager.getCurrentProgram(for: channel)?.programmeName
                         ?? String(localized: "Live"))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                        // The playing programme is where a show is pinned, as in the full
                        // player (F33).
                        .contextMenu {
                            if let programme = serviceManager.getCurrentProgram(for: channel) {
                                FavouriteShowButton(episode: programme, preferences: preferences)
                            }
                        }
                }
            } else {
                Text("Not Playing")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary)
            }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var playPause: some View {
        Button {
            if let playing = serviceManager.playingChannel {
                serviceManager.togglePlayback(for: playing)
            } else if let channel = channel ?? serviceManager.availableChannels.first {
                serviceManager.playChannel(channel)
                selectionState.selectChannel(channel, showSheet: false)
            }
        } label: {
            Image(systemName: serviceManager.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.primary)
                .frame(width: Self.artworkSide, height: Self.artworkSide)
                .contentShape(Circle())
        }
        .disabled(channel == nil && serviceManager.availableChannels.isEmpty)
        .accessibilityLabel(serviceManager.isPlaying ? "Pause" : "Play")
        .accessibilityIdentifier("miniPlayer.playPause")
    }

    @ViewBuilder
    private var share: some View {
        if let playing = serviceManager.playingChannel {
            ShareLink(
                item: SharedChannel(
                    activity: RadioShareActivity(channel: playing),
                    text: "\(playing.qualifiedName)\n\(DeepLinkHandler.generateDeepLinkString(for: playing))"),
                preview: SharePreview(playing.qualifiedName)
            ) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .frame(width: Self.artworkSide, height: Self.artworkSide)
                    .contentShape(Circle())
            }
            .help("Share")
            .accessibilityLabel("Share")
        }
    }
}

/// Liquid Glass on macOS 26, as the iPad's mini player is drawn; a material capsule before.
private struct MiniPlayerGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        }
    }
}
#endif
