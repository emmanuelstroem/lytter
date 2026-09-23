//
//  tvOSNowPlayingViewV2.swift
//  lytter
//
//  Created by Assistant on 08/08/2025.
//

import SwiftUI
#if canImport(GroupActivities)
import GroupActivities
#endif

// MARK: - V2: Full Background Artwork with Centered Text
#if os(tvOS)
struct tvOSNowPlayingViewV2: View {
    @ObservedObject var serviceManager: DRServiceManager
    @State private var showingInfoSheet = false

    var body: some View {
        ZStack {
            if let channel = serviceManager.playingChannel {
                // Full background artwork
                tvOSNowPlayingBackgroundV2(channel: channel, serviceManager: serviceManager)
                    .ignoresSafeArea()
                
                // Overlay content with proper layout
                VStack(spacing: 0) {
                    // Top section - description centered below menu bar
                    VStack {
                        // Push content down to account for menu bar
                        
                        // Description view
                        tvOSNowPlayingDescriptionV2(channel: channel, serviceManager: serviceManager)
                        
//                        Spacer()
                    }
//                    .frame(maxHeight: .infinity)
                    // Bottom section - controls always visible at bottom
                    VStack(spacing: 24) {
                        // Live indicator
                        tvOSLiveIndicatorV2()
                        
                        // Action buttons
                        tvOSActionButtonsV2(
                            showingInfoSheet: $showingInfoSheet,
                            serviceManager: serviceManager
                        )
                    }
                    .padding(.vertical, 40)
//                    .background(
//                        // Dark background to ensure visibility
//                        LinearGradient(
//                            colors: [
//                                Color.black.opacity(0.4),
//                                Color.black.opacity(0.7),
//                                Color.black.opacity(0.9)
//                            ],
//                            startPoint: .top,
//                            endPoint: .bottom
//                        )
//                        .allowsHitTesting(false)
//                    )
                }
                .sheet(isPresented: $showingInfoSheet) {
                    if let channel = serviceManager.playingChannel {
                        tvOSNowPlayingInfoSheetV2(
                            channel: channel,
                            program: serviceManager.getCurrentProgram(for: channel),
                            track: serviceManager.currentTrack
                        )
                    }
                }
            } else {
                // Empty state
                tvOSEmptyStateV2(serviceManager: serviceManager)
            }
        }
    }
}

// MARK: - Background Artwork
struct tvOSNowPlayingBackgroundV2: View {
    let channel: DRChannel
    @ObservedObject var serviceManager: DRServiceManager
    
    var body: some View {
        let imageURL: URL? = {
            if let program = serviceManager.getCurrentProgram(for: channel), 
               let url = program.landscapeImageURL ?? program.primaryImageURL { 
                return URL(string: url) 
            }
            return nil
        }()
        
        ZStack {
            // Background artwork
            Group {
                if let url = imageURL {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .opacity(0.4) // More subtle for background
                    } placeholder: {
                        LinearGradient(
                            colors: [.purple.opacity(0.6), .blue.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                } else {
                    LinearGradient(
                        colors: [.purple.opacity(0.6), .blue.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            
            // Dark overlay for text readability
            LinearGradient(
                colors: [
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.6),
                    Color.black.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Centered Description
struct tvOSNowPlayingDescriptionV2: View {
    let channel: DRChannel
    @ObservedObject var serviceManager: DRServiceManager
    
    var body: some View {
        let program = serviceManager.getCurrentProgram(for: channel)
        let track = serviceManager.currentTrack
        let descriptionText = program?.description ?? ""
        
        VStack(spacing: 30) {
            // Channel and program info at top
            VStack(spacing: 12) {
                // Channel name
                Text(channel.title)
                    .font(.system(size: 48, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                    .multilineTextAlignment(.center)
                
                // Program title
                if let programTitle = program?.cleanTitle(), !programTitle.isEmpty {
                    Text(programTitle)
                        .font(.system(size: 28, weight: .semibold, design: .default))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                        .multilineTextAlignment(.center)
                }
                
                // Current track info
                if let track = track {
                    VStack(spacing: 6) {
                        Text(track.displayText)
                            .font(.system(size: 22, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)
                }
            }
            
            // Description text in center - scrollable with fixed height
            if !descriptionText.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(descriptionText)
                        .font(.system(size: 32, weight: .regular, design: .default))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 80)
                        .padding(.vertical, 40)
                        .lineLimit(10)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 400) // Fixed height to prevent overflow
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.6)
                        .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 8)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .frame(maxWidth: 900)
            }
        }
        .frame(maxWidth: 1000)
        .frame(maxWidth: .infinity, alignment: .center) // Center the entire content
    }
}

// MARK: - Live Indicator
struct tvOSLiveIndicatorV2: View {
    var body: some View {
        HStack(spacing: 16) {
            // Left decorative line with fade
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .frame(maxWidth: .infinity)
            
            // Live indicator content
            Text("LIVE")
                .font(.system(size: 16, weight: .medium, design: .default))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                )
            
            // Right decorative line with fade
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: 1000)
    }
}

// MARK: - Action Buttons
struct tvOSActionButtonsV2: View {
    @Binding var showingInfoSheet: Bool
    @ObservedObject var serviceManager: DRServiceManager
    @FocusState private var focusedButton: ButtonType?
    
    enum ButtonType: Hashable {
        case info, shareplay
    }
    
    var body: some View {
        HStack(spacing: 40) {
            // Info button - Icon only, capsule shape
            Button(action: { showingInfoSheet = true }) {
                Image(systemName: "info.circle")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .focused($focusedButton, equals: .info)
            
            Spacer()
            
            // SharePlay button - Icon only, capsule shape
            Button(action: {
                if let channel = serviceManager.playingChannel {
                    startSharePlay(for: channel)
                }
            }) {
                Image(systemName: "shareplay")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .focused($focusedButton, equals: .shareplay)
        }
        .frame(maxWidth: 1000)
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
struct tvOSEmptyStateV2: View {
    @ObservedObject var serviceManager: DRServiceManager
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.black, .black.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
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
}

// MARK: - Info Sheet
struct tvOSNowPlayingInfoSheetV2: View {
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
