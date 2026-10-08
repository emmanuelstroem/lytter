//
//  MiniPlayer.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import SwiftUI
import AVKit

// MARK: - Mini Player Configuration
struct MiniPlayerConfig {
    let showAirPlayButton: Bool
    let showPlayPauseButton: Bool
    let showChannelInfo: Bool
    let showArtwork: Bool
    
    static let full = MiniPlayerConfig(
        showAirPlayButton: true,
        showPlayPauseButton: true,
        showChannelInfo: true,
        showArtwork: true
    )
    
    static let minimized = MiniPlayerConfig(
        showAirPlayButton: false,
        showPlayPauseButton: true,
        showChannelInfo: true,
        showArtwork: true
    )
    
    static let liquidGlass = MiniPlayerConfig(
        showAirPlayButton: true, // Will be overridden by environment
        showPlayPauseButton: true,
        showChannelInfo: true,
        showArtwork: true
    )
}

// MARK: - Shared Mini Player Components
struct MiniPlayerComponents: View {
    let playingChannel: DRChannel?
    @EnvironmentObject var serviceManager: DRServiceManager
    @EnvironmentObject var selectionState: SelectionState
    let config: MiniPlayerConfig
    
    var body: some View {
        HStack(spacing: 12) {
            // Left: Artwork & Info (tappable for full player)
            HStack(spacing: 12) {
                // Artwork
                if config.showArtwork {
                    if let playingChannel = playingChannel {
                        ChannelArtworkView(
                            playingChannel: playingChannel,
                            size: 36
                        )
                        .environmentObject(serviceManager)
                    } else if let lastPlayedChannel = serviceManager.userPreferences.lastPlayedChannel,
                              serviceManager.findLastPlayedChannel(in: serviceManager.availableChannels) != nil {
                        ChannelArtworkView(
                            playingChannel: lastPlayedChannel,
                            size: 36
                        )
                        .environmentObject(serviceManager)
                        .opacity(0.7)
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.gray.opacity(0.6), .gray.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1.2)
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
                    }
                }
                // Channel Info
                if config.showChannelInfo {
                    VStack(alignment: .leading, spacing: 1) {
                        if let playingChannel = playingChannel {
                            if let track = serviceManager.currentTrack {
                                if serviceManager.isHeard(track) {
                                    let programTitle = serviceManager.getCurrentProgram(for: playingChannel)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(verbatim: "\(playingChannel.title) - \(programTitle?.cleanTitle() ?? "")")
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(Color.primary)
                                            .lineLimit(1)
                                        MarqueeText(
                                            text: track.displayText,
                                            font: .caption2,
                                            leftFade: 5,
                                            rightFade: 24,
                                            startDelay: 1.5
                                        )
                                        .foregroundStyle(Color.secondary)
                                    }
                                } else {
                                    let programTitle = serviceManager.getCurrentProgram(for: playingChannel)?.cleanTitle() ?? String(localized: "Live")
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(playingChannel.title)
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(Color.primary)
                                            .lineLimit(1)
                                        MarqueeText(
                                            text: programTitle,
                                            font: .caption2,
                                            leftFade: 5,
                                            rightFade: 24,
                                            startDelay: 1.5
                                        )
                                        .foregroundStyle(Color.secondary)
                                    }
                                }
                            } else if let currentProgram = serviceManager.getCurrentProgram(for: playingChannel) {
                                Text(playingChannel.title)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(Color.primary)
                                    .lineLimit(1)
                                MarqueeText(
                                    text: currentProgram.cleanTitle(),
                                    font: .caption2,
                                    leftFade: 5,
                                    rightFade: 24,
                                    startDelay: 1.5
                                )
                                .foregroundStyle(Color.secondary)
                            } else {
                                Text(serviceManager.isPlaying ? "Live Now" : "Paused")
                                    .font(.footnote.weight(.medium))
                                    .foregroundColor(serviceManager.isPlaying ? Color.red : Color.secondary)
                                    .lineLimit(1)
                            }
                        } else {
                            if let lastPlayedChannel = serviceManager.userPreferences.lastPlayedChannel,
                               serviceManager.findLastPlayedChannel(in: serviceManager.availableChannels) != nil {
                                let programTitle = serviceManager.getCurrentProgram(for: lastPlayedChannel)?.cleanTitle() ?? String(localized: "Live")
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(lastPlayedChannel.title)
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(Color.primary)
                                        .lineLimit(1)
                                    MarqueeText(
                                        text: programTitle,
                                        font: .caption2,
                                        leftFade: 5,
                                        rightFade: 24,
                                        startDelay: 1.5
                                    )
                                    .foregroundStyle(Color.secondary)
                                }
                            } else {
                                Text("Not Playing")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(Color.primary)
                                    .lineLimit(1)
                                Text(serviceManager.availableChannels.isEmpty ? "No channels available" : "Tap play to start")
                                    .font(.caption2)
                                    .foregroundStyle(Color.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Text styles now, so the bar follows Dynamic Type — but it is a fixed-height
                    // bar, so it stops growing where the system's own compact bars do.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { selectionState.isShowingFullPlayer = true }
            // One element rather than a stack of separate Texts, and marked as a button:
            // as a plain tap gesture there was nothing to tell VoiceOver this opens
            // anything.
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens the player")
            .accessibilityIdentifier("miniPlayer")

            // Right: Controls
            HStack(spacing: 12) {
                if config.showAirPlayButton {
                    AirPlayButtonView(size: 24)
                        .opacity(playingChannel != nil ? 1.0 : 0.3)
                        .disabled(playingChannel == nil)
                }
                if config.showPlayPauseButton {
                    Button(action: {
                        if let playingChannel = playingChannel {
                            serviceManager.togglePlayback(for: playingChannel)
                        } else if let lastPlayedChannel = serviceManager.userPreferences.lastPlayedChannel,
                                  serviceManager.findLastPlayedChannel(in: serviceManager.availableChannels) != nil {
                            serviceManager.playChannel(lastPlayedChannel)
                        } else if let firstChannel = serviceManager.availableChannels.first {
                            serviceManager.playChannel(firstChannel)
                        }
                    }) {
                        Image(systemName: serviceManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.primary)
                            #if os(visionOS)
                            .frame(width: 36, height: 36)
                            #else
                            .frame(width: 32, height: 32)
                            #endif
                    }
                    #if os(visionOS)
                    // visionOS draws a platter behind the button, and at the ornament's end it
                    // meets the corner the artwork meets at the other: the same size, inset
                    // and radius as the artwork, so both share the ornament's curve. Its own
                    // capsule was rounder than the corner around it.
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                    #endif
                    .disabled(playingChannel == nil && serviceManager.availableChannels.isEmpty)
                    .accessibilityLabel(serviceManager.isPlaying ? "Pause" : "Play")
                }
            }
            .frame(alignment: .trailing)
        }
        #if os(visionOS)
        // In visionOS's ornament the artwork meets the glass's corner, so it is inset the
        // same on every side; the ornament's radius is this plus the artwork's.
        .padding(10)
        #else
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        #endif
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Main Mini Player

struct MiniPlayer: View {
    @EnvironmentObject var serviceManager: DRServiceManager
    @EnvironmentObject var selectionState: SelectionState
    
    var body: some View {
        if #available(iOS 26.0, tvOS 26.0, macOS 26.0, *) {
            LiquidGlassMiniPlayer()
                .environmentObject(serviceManager)
                .environmentObject(selectionState)
            
        } else {
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    MiniPlayerComponents(
                        playingChannel: serviceManager.playingChannel,
                        config: .full
                    )
                    .environmentObject(serviceManager)
                    .environmentObject(selectionState)
                    .id(serviceManager.playingChannel?.id ?? "no-channel")
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .opacity(0.9)
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 25) // 25 is standard TabBar height
                }
            }
        }
    }
}

// MARK: - LiquidGlass Mini Player (iOS/tvOS/macOS 26+)
@available(iOS 26.0, tvOS 26.0, macOS 26.0, *)
struct LiquidGlassMiniPlayer: View {
    @EnvironmentObject var serviceManager: DRServiceManager
    @EnvironmentObject var selectionState: SelectionState
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    
    var body: some View {
        switch placement {
            case .inline:
                MiniPlayerComponents(
                    playingChannel: serviceManager.playingChannel,
                    config: MiniPlayerConfig(
                        showAirPlayButton: false,
                        showPlayPauseButton: true,
                        showChannelInfo: true,
                        showArtwork: true
                    )
                )
                .environmentObject(serviceManager)
                .environmentObject(selectionState)
                .id(serviceManager.playingChannel?.id ?? "no-channel")
            default:
                MiniPlayerComponents(
                    playingChannel: serviceManager.playingChannel,
                    config: MiniPlayerConfig(
                        showAirPlayButton: true,
                        showPlayPauseButton: true,
                        showChannelInfo: true,
                        showArtwork: true
                    )
                )
                .environmentObject(serviceManager)
                .environmentObject(selectionState)
                .id(serviceManager.playingChannel?.id ?? "no-channel")
        }
    }
}

// MARK: - Shared Channel Artwork View
struct ChannelArtworkView: View {
    let playingChannel: DRChannel
    @EnvironmentObject var serviceManager: DRServiceManager
    let size: CGFloat
    
    var body: some View {
        // The station's colour and name while the picture loads, when there is none, and
        // when Show Images is off.
        CachedAsyncImage(url: artworkURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            StationArtworkPlaceholder(channel: playingChannel)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
    }

    private var artworkURL: URL? {
        serviceManager.getCurrentProgram(for: playingChannel)?.primaryImageURL
            .flatMap(URL.init(string:))
    }
}

#Preview {
    MiniPlayer()
        .environmentObject(DRServiceManager())
        .environmentObject(SelectionState())
} 
