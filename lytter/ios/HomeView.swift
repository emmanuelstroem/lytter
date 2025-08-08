//
//  HomeView.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import SwiftUI

#if os(iOS)
struct HomeView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    @ObservedObject var deepLinkHandler: DeepLinkHandler
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color.black,
                        Color.black.opacity(0.95),
                        Color.black.opacity(0.9)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        HomeHeader()
                        
                        if serviceManager.isLoading {
                            LoadingView()
                        } else if let error = serviceManager.error {
                            ErrorView(error: error) {
                                serviceManager.loadChannels()
                            }
                        } else if serviceManager.availableChannels.isEmpty {
                            EmptyStateView()
                        } else {
                            DRChannelsSection(
                                serviceManager: serviceManager,
                                onChannelTap: { channel in
                                    // Start streaming the channel
                                    serviceManager.playChannel(channel)
                                    selectionState.selectChannel(channel, showSheet: false)
                                }
                            )
                        }
                        
                        // Playback error alert
                        if let playbackError = serviceManager.playbackError {
                            PlaybackErrorAlert(
                                error: playbackError,
                                onDismiss: {
                                    serviceManager.clearPlaybackError()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100) // Space for bottom tab bar
                }
            }
        }
        .onChange(of: deepLinkHandler.shouldNavigateToChannel) { oldValue, newValue in
            print("🏠 HomeView: shouldNavigateToChannel changed to: \(newValue)")
            if newValue, let targetChannel = deepLinkHandler.targetChannel {
                print("🏠 HomeView: Handling deep link for channel: \(targetChannel.id)")
                handleDeepLinkChannel(targetChannel)
            }
        }
        .onChange(of: serviceManager.availableChannels.count) { oldCount, newCount in
            print("🏠 HomeView: Channel count changed to: \(newCount)")
            // If we have a pending deep link and channels are now loaded, retry
            if newCount > 0 && deepLinkHandler.pendingChannelId != nil {
                print("🏠 HomeView: Channels loaded, retrying pending deep link")
                deepLinkHandler.retryPendingDeepLink()
            }
        }
    }
    
    private func handleDeepLinkChannel(_ targetChannel: DRChannel) {
        print("🏠 HomeView: handleDeepLinkChannel called for channel: \(targetChannel.id)")
        print("🏠 HomeView: Available channels count: \(serviceManager.availableChannels.count)")
        
        // Find the actual channel in available channels
        if let actualChannel = serviceManager.availableChannels.first(where: { $0.id == targetChannel.id }) {
            print("🏠 HomeView: Found actual channel: \(actualChannel.title)")
            // Play the channel
            serviceManager.playChannel(actualChannel)
            selectionState.selectChannel(actualChannel, showSheet: false)
            print("🏠 HomeView: Started playing channel")
        } else {
            print("🏠 HomeView: Channel not found in available channels")
            // If channels aren't loaded yet, try to load them and retry
            if serviceManager.availableChannels.isEmpty {
                print("🏠 HomeView: No channels loaded, loading channels...")
                serviceManager.loadChannels()
            }
        }
        
        // Clear the deep link target
        deepLinkHandler.clearTarget()
    }
}

#endif

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            
            Text("Loading channels...")
                .font(.headline)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Error View
struct ErrorView: View {
    let error: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Error loading channels")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Retry") {
                retryAction()
            }
            .foregroundColor(.blue)
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "radio")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No channels available")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Try refreshing to load channels")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Home Header
struct HomeHeader: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lyt")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Live Danish Radio")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // User profile picture
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
        }
        .padding(.top, 8)
    }
}

// MARK: - Grouped Channel Structure
struct GroupedChannel: Identifiable {
    let id: String
    let name: String
    let channels: [DRChannel]
    
    init(channels: [DRChannel]) {
        self.channels = channels
        self.name = channels.first?.name ?? ""
        self.id = channels.first?.id ?? ""
    }
    
    var hasMultipleDistricts: Bool {
        return channels.count > 1
    }
    
    var districts: [String] {
        return channels.compactMap { $0.district }.uniqued()
    }
}

// MARK: - DR Channels Section
struct DRChannelsSection: View {
    @ObservedObject var serviceManager: DRServiceManager
    let onChannelTap: (DRChannel) -> Void
    
    private var groupedChannels: [GroupedChannel] {
        let channels = serviceManager.availableChannels
        let grouped = Dictionary(grouping: channels) { $0.name }
        return grouped.values.map { GroupedChannel(channels: $0) }
            .sorted { $0.name < $1.name }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("DR")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            // Channels grid with responsive layout
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)
            ], spacing: 12) {
                ForEach(groupedChannels) { groupedChannel in
                    GroupedChannelCard(
                        groupedChannel: groupedChannel,
                        serviceManager: serviceManager,
                        onTap: onChannelTap,
                        cardWidth: 160,
                        cardHeight: 100
                    )
                    .id(groupedChannel.id) // Ensure unique identification
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Grouped Channel Card
struct GroupedChannelCard: View {
    let groupedChannel: GroupedChannel
    @ObservedObject var serviceManager: DRServiceManager
    let onTap: (DRChannel) -> Void
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    @State private var showingDistrictSheet = false
    
    private var primaryChannel: DRChannel {
        return groupedChannel.channels.first!
    }
    
    private var channelColor: Color {
        // DR Radio channel color themes
        switch primaryChannel.title.lowercased() {
            case let title where title.contains("p1"):
                return Color.orange // Dark Orange for P1
            case let title where title.contains("p2"):
                return Color.blue // Blue for P2
            case let title where title.contains("p3"):
                return Color.green // Neon Green for P3
            case let title where title.contains("p4"):
                return Color.yellow // Light Orange/Yellow for P4
            case let title where title.contains("p5"):
                return Color.pink // Pink for P5
            case let title where title.contains("p6"):
                return Color.gray // Gray for P6
            case let title where title.contains("p8"):
                return Color.purple // Purple for P8
            default:
                // Fallback to hash-based color for other channels
                let hash = abs(primaryChannel.id.hashValue)
                let hue = Double(hash % 360) / 360.0
                let saturation = 0.7 + Double(hash % 20) / 100.0
                let brightness = 0.8 + Double(hash % 20) / 100.0
                return Color(hue: hue, saturation: saturation, brightness: brightness)
        }
    }
    
    var body: some View {
        Button(action: {
            if groupedChannel.hasMultipleDistricts {
                showingDistrictSheet = true
            } else {
                onTap(primaryChannel)
            }
        }) {
            ZStack {
                // Background image or gradient
                if let currentProgram = serviceManager.getCurrentProgram(for: primaryChannel),
                   let imageURL = currentProgram.primaryImageURL,
                   let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: cardWidth, height: cardHeight)
                            .clipped()
                            .blur(radius: 2)
                            .overlay(
                                // Dark overlay to reduce brightness
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.6))
                            )
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        channelColor.opacity(0.7),
                                        channelColor.opacity(0.5),
                                        channelColor.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: cardWidth, height: cardHeight)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    channelColor.opacity(0.7),
                                    channelColor.opacity(0.5),
                                    channelColor.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: cardWidth, height: cardHeight)
                }
                
                // Content overlay
                VStack(alignment: .leading, spacing: 4) {
                    Spacer()
                    
                    HStack {
                        // Channel name and district indicator
                        HStack(alignment: .bottom, spacing: 2) {
                            // Channel title in square view with KnockoutTextView
                            KnockoutTextView(
                                text: groupedChannel.name,
                                backgroundColor: channelColor
                            )
                            .frame(width: min(50, cardWidth * 0.3), height: min(50, cardHeight * 0.5))
                            .cornerRadius(6)
                            
                            if groupedChannel.hasMultipleDistricts {
                                HStack(spacing: 4) {
                                    Text("\(groupedChannel.districts.count) districts")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(channelColor)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(channelColor)
                                }
                            } else if let district = primaryChannel.district {
                                Text(district)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(channelColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle()) // Ensure the entire card area is tappable
        .sheet(isPresented: $showingDistrictSheet) {
            DistrictSelectionSheet(
                groupedChannel: groupedChannel,
                onChannelSelect: onTap
            )
        }
    }
}

// MARK: - Playback Error Alert
struct PlaybackErrorAlert: View {
    let error: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
                
                Text("Playback Error")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .opacity(0.9)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: error)
    }
}

// MARK: - Glass Effect Container
//@available(iOS 26.0, *)
//struct GlassEffectContainer<Content: View>: View {
//    let content: Content
//    
//    init(@ViewBuilder content: () -> Content) {
//        self.content = content()
//    }
//    
//    var body: some View {
//        content
//            .background(.ultraThinMaterial)
//            .clipShape(RoundedRectangle(cornerRadius: 16))
//            .overlay(
//                RoundedRectangle(cornerRadius: 16)
//                    .stroke(.white.opacity(0.2), lineWidth: 1)
//            )
//    }
//}

#Preview {
    HomeView(
        serviceManager: DRServiceManager(),
        selectionState: SelectionState(),
        deepLinkHandler: DeepLinkHandler()
    )
}
