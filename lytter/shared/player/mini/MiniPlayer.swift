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
    @State private var showingFullPlayer = false
    
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
                                if track.isCurrentlyPlaying {
                                    let programTitle = serviceManager.getCurrentProgram(for: playingChannel)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("\(playingChannel.title) - \(programTitle?.cleanTitle() ?? "")")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        MarqueeText(
                                            text: track.displayText,
                                            font: .system(size: 11, weight: .regular),
                                            leftFade: 5,
                                            rightFade: 24,
                                            startDelay: 1.5
                                        )
                                        .foregroundColor(.gray)
                                    }
                                } else {
                                    let programTitle = serviceManager.getCurrentProgram(for: playingChannel)?.cleanTitle() ?? "Live"
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(playingChannel.title)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        MarqueeText(
                                            text: programTitle,
                                            font: .system(size: 11, weight: .regular),
                                            leftFade: 5,
                                            rightFade: 24,
                                            startDelay: 1.5
                                        )
                                        .foregroundColor(.gray)
                                    }
                                }
                            } else if let currentProgram = serviceManager.getCurrentProgram(for: playingChannel) {
                                Text(playingChannel.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                MarqueeText(
                                    text: currentProgram.cleanTitle(),
                                    font: .system(size: 11, weight: .regular),
                                    leftFade: 5,
                                    rightFade: 24,
                                    startDelay: 1.5
                                )
                                .foregroundColor(.gray)
                            } else {
                                Text(serviceManager.isPlaying ? "Live Now" : "Paused")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(serviceManager.isPlaying ? .red : .gray)
                                    .lineLimit(1)
                            }
                        } else {
                            if let lastPlayedChannel = serviceManager.userPreferences.lastPlayedChannel,
                               serviceManager.findLastPlayedChannel(in: serviceManager.availableChannels) != nil {
                                let programTitle = serviceManager.getCurrentProgram(for: lastPlayedChannel)?.cleanTitle() ?? "Live"
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(lastPlayedChannel.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    MarqueeText(
                                        text: programTitle,
                                        font: .system(size: 11, weight: .regular),
                                        leftFade: 5,
                                        rightFade: 24,
                                        startDelay: 1.5
                                    )
                                    .foregroundColor(.gray)
                                }
                            } else {
                                Text("Not Playing")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(serviceManager.availableChannels.isEmpty ? "No channels available" : "Tap play to start")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { showingFullPlayer = true }

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
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                    }
                    .disabled(playingChannel == nil && serviceManager.availableChannels.isEmpty)
                }
            }
            .frame(alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showingFullPlayer) {
            FullPlayerSheet(serviceManager: serviceManager, selectionState: selectionState)
        }
    }
}

// MARK: - Main Mini Player

struct MiniPlayer: View {
    @EnvironmentObject var serviceManager: DRServiceManager
    @EnvironmentObject var selectionState: SelectionState
    
    var body: some View {
        if #available(iOS 26.0, tvOS 26.0, *) {
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
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 25) // 25 is standard TabBar height
                }
            }
        }
    }
}

// MARK: - LiquidGlass Mini Player (iOS 26+)
@available(iOS 26.0, tvOS 26.0, *)
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
    
    private var channelIcon: String {
        // Get the current program and use its category-based icon
        if let currentProgram = serviceManager.getCurrentProgram(for: playingChannel) {
            return currentProgram.categoryIcon
        }
        
        // Fallback to default radio icon if no current program
        return "antenna.radiowaves.left.and.right"
    }
    
    var body: some View {
        if let currentProgram = serviceManager.getCurrentProgram(for: playingChannel),
           let imageURL = currentProgram.primaryImageURL,
           let url = URL(string: imageURL) {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.8), .blue.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Image(systemName: channelIcon)
                            .font(.system(size: size * 0.4, weight: .medium))
                            .foregroundColor(.white)
                    }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1.2)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.purple.opacity(0.8), .blue.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: channelIcon)
                        .font(.system(size: size * 0.4, weight: .medium))
                        .foregroundColor(.white)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1.2)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
        }
    }
}

#Preview {
    MiniPlayer()
        .environmentObject(DRServiceManager())
        .environmentObject(SelectionState())
} 
