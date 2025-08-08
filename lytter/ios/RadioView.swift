//
//  RadioView.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import SwiftUI

struct RadioView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    @ObservedObject var deepLinkHandler: DeepLinkHandler
    @State private var searchText = ""
    @State private var isLoading = false
    
    var filteredGroupedChannels: [GroupedChannel] {
        let channels = serviceManager.availableChannels
        let grouped = Dictionary(grouping: channels) { $0.name }
        let groupedChannels = grouped.values.map { GroupedChannel(channels: $0) }
            .sorted { $0.name < $1.name }
        
        if searchText.isEmpty {
            return groupedChannels
        } else {
            return groupedChannels.filter { groupedChannel in
                groupedChannel.name.localizedCaseInsensitiveContains(searchText) ||
                groupedChannel.channels.contains { channel in
                    channel.displayName.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
    }
    
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
                
                VStack(spacing: 0) {
                    // Search bar
                    SearchBar(text: $searchText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    
                    // Channel list
                    if serviceManager.isLoading {
                        LoadingView()
                    } else if let error = serviceManager.error {
                        ErrorView(error: error) {
                            serviceManager.loadChannels()
                        }
                    } else if filteredGroupedChannels.isEmpty {
                        EmptyStateView()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredGroupedChannels) { groupedChannel in
                                    GroupedRadioChannelCard(
                                        groupedChannel: groupedChannel,
                                        serviceManager: serviceManager,
                                        onTap: { channel in
                                            // Start streaming the channel
                                            serviceManager.playChannel(channel)
                                            selectionState.selectChannel(channel, showSheet: false)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 100) // Space for mini player
                        }
                    }
                }
            }
            .navigationTitle("Radio")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            // Load channels if not already loaded
            if serviceManager.availableChannels.isEmpty {
                serviceManager.loadChannels()
            }
        }
        .onChange(of: deepLinkHandler.shouldNavigateToChannel) { shouldNavigate in
            if shouldNavigate, let targetChannel = deepLinkHandler.targetChannel {
                handleDeepLinkChannel(targetChannel)
            }
        }
    }
    
    private func handleDeepLinkChannel(_ targetChannel: DRChannel) {
        // Find the actual channel in available channels
        if let actualChannel = serviceManager.availableChannels.first(where: { $0.id == targetChannel.id }) {
            // Play the channel
            serviceManager.playChannel(actualChannel)
            selectionState.selectChannel(actualChannel, showSheet: false)
        }
        
        // Clear the deep link target
        deepLinkHandler.clearTarget()
    }
}



// MARK: - Grouped Radio Channel Card
struct GroupedRadioChannelCard: View {
    let groupedChannel: GroupedChannel
    let serviceManager: DRServiceManager
    let onTap: (DRChannel) -> Void
    
    @State private var isPressed = false
    @State private var showingDistrictSheet = false
    
    private var primaryChannel: DRChannel {
        return groupedChannel.channels.first!
    }
    
    private var channelColor: Color {
        // Generate a consistent color based on channel ID
        let hash = abs(primaryChannel.id.hashValue)
        let hue = Double(hash % 360) / 360.0
        let saturation = 0.6 + Double(hash % 20) / 100.0
        let brightness = 0.7 + Double(hash % 20) / 100.0
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
    
    var body: some View {
        Button(role: .none, action: {
            if groupedChannel.hasMultipleDistricts {
                showingDistrictSheet = true
            } else {
                onTap(primaryChannel)
            }
        }) {
            HStack(spacing: 16) {
                // Channel artwork with real image or fallback
                AsyncImage(url: getChannelImageURL()) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: channelColor.opacity(0.3), radius: 4, x: 0, y: 2)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    channelColor.opacity(0.9),
                                    channelColor.opacity(0.7),
                                    channelColor.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: channelColor.opacity(0.3), radius: 4, x: 0, y: 2)
                        .overlay {
                            // Channel title in square view with KnockoutTextView
                            KnockoutTextView(
                                text: groupedChannel.name,
                                backgroundColor: channelColor
                            )
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                        }
                }
                
                // Channel info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(groupedChannel.name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if groupedChannel.hasMultipleDistricts {
                            HStack(spacing: 4) {
                                Text("(\(groupedChannel.districts.count))")
                                    .font(.caption)
                                    .foregroundColor(channelColor)
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(channelColor)
                            }
                        }
                    }
                    
                    // Show current program or track info
                    if let program = getCurrentProgram() {
                        Text(program.cleanTitle())
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    } else if let track = getCurrentTrack() {
                        Text(track.displayText)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    } else {
                        Text(primaryChannel.type.capitalized)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .sheet(isPresented: $showingDistrictSheet) {
            DistrictSelectionSheet(
                groupedChannel: groupedChannel,
                onChannelSelect: onTap
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func getChannelImageURL() -> URL? {
        // Try to get image from current program first
        if let program = getCurrentProgram(),
           let imageURLString = program.primaryImageURL {
            return URL(string: imageURLString)
        }
        
        // Try to get image from any cached program for this channel
        let channelPrograms = serviceManager.getCachedPrograms(for: primaryChannel)
        if let programWithImage = channelPrograms.first(where: { $0.primaryImageURL != nil }),
           let imageURLString = programWithImage.primaryImageURL {
            return URL(string: imageURLString)
        }
        
        return nil
    }
    
    private func getCurrentProgram() -> DREpisode? {
        return serviceManager.getCurrentProgram(for: primaryChannel)
    }
    
    private func getCurrentTrack() -> DRTrack? {
        return serviceManager.currentTrack
    }
}









#Preview {
    RadioView(
        serviceManager: DRServiceManager(),
        selectionState: SelectionState(),
        deepLinkHandler: DeepLinkHandler()
    )
}





// MARK: - KnockoutTextView Components
struct KnockoutTextView: View {
    var text: String
    var backgroundColor: Color = .blue
    
    var body: some View {
        ZStack {
            // Square with transparent text
            TextMaskView(text: text, backgroundColor: backgroundColor)
        }
    }
}

struct TextMaskView: View {
    var text: String
    var backgroundColor: Color
    
    var body: some View {
        // Solid color square
        backgroundColor
            .overlay {
                // Transparent text mask - using fixed size instead of GeometryReader
                Text(text)
                    .font(.system(size: 24, weight: .black, design: .default))
                    .minimumScaleFactor(0.1)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(.black)
                    .blendMode(.destinationOut) // Punch out the text
            }
            .compositingGroup() // Required for destinationOut to work properly
    }
} 
