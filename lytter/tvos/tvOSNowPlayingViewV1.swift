//
//  tvOSNowPlayingViewV1.swift
//  lytter
//
//  Created by Assistant on 08/08/2025.
//

import SwiftUI
#if canImport(GroupActivities)
import GroupActivities
#endif

// MARK: - V1: Side-by-Side Layout
#if os(tvOS)
struct tvOSNowPlayingViewV1: View {
    @ObservedObject var serviceManager: DRServiceManager
    @State private var showingInfoSheet = false

    var body: some View {
        ZStack {
            // Apple-style background gradient
            LinearGradient(
                colors: [.black, .black.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if let channel = serviceManager.playingChannel {
                VStack(spacing: 60) {
                    // Main content area
                    tvOSNowPlayingContentV1(channel: channel, serviceManager: serviceManager)
                    
                    // Bottom controls
                    VStack(spacing: 40) {
                        // Live indicator with Apple-style design
                        tvOSLiveIndicatorV1()
                        
                        // Action buttons aligned with content width
                        tvOSActionButtonsV1(
                            showingInfoSheet: $showingInfoSheet,
                            serviceManager: serviceManager
                        )
                    }
                }
                .padding(.vertical, 60)
                .sheet(isPresented: $showingInfoSheet) {
                    if let channel = serviceManager.playingChannel {
                        tvOSNowPlayingInfoSheetV1(
                            channel: channel,
                            program: serviceManager.getCurrentProgram(for: channel),
                            track: serviceManager.currentTrack
                        )
                    }
                }
            } else {
                // Empty state with Apple-style design
                tvOSEmptyStateV1(serviceManager: serviceManager)
            }
        }
    }
}

// MARK: - Main Content Area
struct tvOSNowPlayingContentV1: View {
    let channel: DRChannel
    @ObservedObject var serviceManager: DRServiceManager
    
    var body: some View {
        let hasInfo = !(serviceManager.getCurrentProgram(for: channel)?.description?.isEmpty ?? true)
        
        if hasInfo {
            // Side-by-side layout when info is available
            HStack(spacing: 40) {
                // Artwork on the left - smaller to give more space for description
                tvOSNowPlayingArtworkV1(channel: channel)
                    .frame(maxWidth: 450, maxHeight: 300)
                
                // Info content on the right - more space for description
                tvOSNowPlayingInfoV1(channel: channel, serviceManager: serviceManager)
                    .frame(maxWidth: 650, maxHeight: 300)
            }
            .frame(maxWidth: 1200) // Total width for side-by-side layout
        } else {
            // Centered artwork when no info
            tvOSNowPlayingArtworkV1(channel: channel)
                .frame(maxWidth: 1000, maxHeight: 600)
        }
    }
}

// MARK: - Info Content
struct tvOSNowPlayingInfoV1: View {
    let channel: DRChannel
    @ObservedObject var serviceManager: DRServiceManager
    
    var body: some View {
        let program = serviceManager.getCurrentProgram(for: channel)
        let track = serviceManager.currentTrack
        let descriptionText = program?.description ?? ""
        
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Current track info
                if let track = track {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Now Playing")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(track.displayText)
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.top, 8)
                }
                
                // Description
                if !descriptionText.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Description")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(descriptionText)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.leading)
                            .lineSpacing(4)
                    }
                }
            }
            .padding(32)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

// MARK: - Artwork
struct tvOSNowPlayingArtworkV1: View {
    let channel: DRChannel
    @EnvironmentObject private var serviceManager: DRServiceManager

    var body: some View {
        let imageURL: URL? = {
            if let program = serviceManager.getCurrentProgram(for: channel), 
               let url = program.landscapeImageURL ?? program.primaryImageURL { 
                return URL(string: url) 
            }
            return nil
        }()

        ZStack(alignment: .bottomLeading) {
            // Main artwork container
            Group {
                if let url = imageURL {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .opacity(0.7) // Dim artwork by 30%
                    } placeholder: {
                        ZStack {
                            LinearGradient(
                                colors: [.purple.opacity(0.8), .blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            
                            Image(systemName: "music.note")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                } else {
                    LinearGradient(
                        colors: [.purple.opacity(0.8), .blue.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .clipped()

            // Gradient overlay for text readability
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .frame(maxWidth: .infinity, alignment: .bottom)
            .allowsHitTesting(false)

            // Text overlays
            VStack(alignment: .leading, spacing: 8) {
                // Channel title
                MarqueeText(
                    text: channel.title,
                    font: .system(size: 32, weight: .bold, design: .default),
                    leftFade: 16,
                    rightFade: 16,
                    startDelay: 1.0,
                    alignment: .leading
                )
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

                // Program title
                if let program = serviceManager.getCurrentProgram(for: channel) {
                    MarqueeText(
                        text: program.cleanTitle(),
                        font: .system(size: 20, weight: .semibold, design: .default),
                        leftFade: 16,
                        rightFade: 16,
                        startDelay: 1.5,
                        alignment: .leading
                    )
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Live Indicator
struct tvOSLiveIndicatorV1: View {
    var body: some View {
        HStack(spacing: 20) {
            // Left decorative line with fade
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3)
                .frame(maxWidth: .infinity)
            
            // Live indicator content
            Text("LIVE")
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                )
            
            // Right decorative line with fade
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.6), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: 1200) // Match content width
    }
}

// MARK: - Action Buttons
struct tvOSActionButtonsV1: View {
    @Binding var showingInfoSheet: Bool
    @ObservedObject var serviceManager: DRServiceManager
    @FocusState private var focusedButton: ButtonType?
    
    enum ButtonType: Hashable {
        case info, shareplay
    }
    
    var body: some View {
        HStack(spacing: 40) {
            // Info button
            Button(action: { showingInfoSheet = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.title2)
                    Text("Info")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(
                            color: focusedButton == .info ? .white.opacity(0.3) : .black.opacity(0.2), 
                            radius: focusedButton == .info ? 12 : 8, 
                            x: 0, 
                            y: focusedButton == .info ? 6 : 4
                        )
                        .scaleEffect(focusedButton == .info ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: focusedButton)
                )
            }
            .buttonStyle(.plain)
            .focused($focusedButton, equals: .info)
            
            Spacer()
            
            // SharePlay button
            Button(action: {
                if let channel = serviceManager.playingChannel {
                    startSharePlay(for: channel)
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "shareplay")
                        .font(.title2)
                    Text("SharePlay")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(
                            color: focusedButton == .shareplay ? .white.opacity(0.3) : .black.opacity(0.2), 
                            radius: focusedButton == .shareplay ? 12 : 8, 
                            x: 0, 
                            y: focusedButton == .shareplay ? 6 : 4
                        )
                        .scaleEffect(focusedButton == .shareplay ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: focusedButton)
                )
            }
            .buttonStyle(.plain)
            .focused($focusedButton, equals: .shareplay)
        }
        .frame(maxWidth: 1200) // Match content width
    }
    
    private func startSharePlay(for channel: DRChannel) {
        #if canImport(GroupActivities)
        if #available(tvOS 15.0, *) {
            struct RadioShareActivity: GroupActivity {
                static let activityIdentifier = "com.eopio.lytter.shareplay.radio"
                let channelId: String
                let channelTitle: String

                var metadata: GroupActivityMetadata {
                    var data = GroupActivityMetadata()
                    data.title = channelTitle
                    data.type = .watchTogether
                    return data
                }
            }

            let activity = RadioShareActivity(channelId: channel.id, channelTitle: channel.title)
            Task {
                do {
                    _ = try await activity.activate()
                } catch {
                    // No-op: activation may fail in simulator or without entitlement
                }
            }
        }
        #endif
    }
}

// MARK: - Empty State
struct tvOSEmptyStateV1: View {
    @ObservedObject var serviceManager: DRServiceManager
    
    var body: some View {
        VStack(spacing: 40) {
            // Icon with Apple-style treatment
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 16) {
                Text("Nothing Playing")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Select a channel to start listening")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            if let first = serviceManager.availableChannels.first {
                Button("Play \(first.title)") {
                    serviceManager.playChannel(first)
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                )
                .buttonStyle(.plain)
                .focusable()
            }
        }
    }
}

// MARK: - Info Sheet
struct tvOSNowPlayingInfoSheetV1: View {
    let channel: DRChannel
    let program: DREpisode?
    let track: DRTrack?

    var body: some View {
        let descriptionText = program?.description ?? "No description available."

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                // Header with channel and program info
                VStack(alignment: .leading, spacing: 16) {
                    // Channel name
                    Text(channel.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    // Program title
                    if let programTitle = program?.cleanTitle(), !programTitle.isEmpty {
                        Text(programTitle)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                    
                    // Current track info
                    if let track = track {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Now Playing")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text(track.displayText)
                                .font(.title3)
                                .foregroundColor(.primary)
                        }
                        .padding(.top, 8)
                    }
                }
                
                // Description
                VStack(alignment: .leading, spacing: 12) {
                    Text("Description")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(descriptionText)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                }
            }
            .padding(48)
        }
        .frame(maxWidth: 800, maxHeight: 600)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}
#endif
