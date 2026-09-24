//
//  HomeView.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import SwiftUI
import os

#if os(iOS)
struct HomeView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    
    var body: some View {
        // No navigation container: this screen has no title, no toolbar and no links,
        // so NavigationView was contributing an empty bar and nothing else. The header
        // it does show is drawn inside the ScrollView.
        ZStack {
            AppBackground()
            
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
                        FavouritesSection(
                            serviceManager: serviceManager,
                            preferences: serviceManager.userPreferences,
                            onChannelTap: { channel in
                                serviceManager.playChannel(channel)
                                selectionState.selectChannel(channel, showSheet: false)
                            }
                        )

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
}

#endif

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle())
            
            Text("Loading channels...")
                .font(.headline)
                .foregroundStyle(Color.primary)
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
                .foregroundStyle(Color.primary)
            
            Text(error)
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Retry") {
                retryAction()
            }
            .foregroundColor(.blue)
            .padding()
            .background(Color(.tertiarySystemFill))
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
                .foregroundStyle(Color.secondary)
            
            Text("No channels available")
                .font(.headline)
                .foregroundStyle(Color.primary)
            
            Text("Try refreshing to load channels")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
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
                    .foregroundStyle(Color.primary)
                
                Text("Live Danish Radio")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
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
// MARK: - DR Channels Section
/// Pinned channels, above the catalogue.
///
/// These are individual channels rather than stations, so a favourited *P4 København*
/// plays on one tap — the district picker is exactly the friction this removes. It draws
/// nothing at all when there are no favourites, rather than an empty heading.
struct FavouritesSection: View {
    @ObservedObject var serviceManager: DRServiceManager
    /// Observed directly. `userPreferences` is its own ObservableObject, and a nested one
    /// does not republish through its owner — observing only `serviceManager` meant pinning
    /// a channel changed the stored list and redrew nothing.
    @ObservedObject var preferences: UserPreferencesService
    let onChannelTap: (DRChannel) -> Void

    private var favourites: [DRChannel] {
        preferences.favourites.resolve(in: serviceManager.availableChannels)
    }

    var body: some View {
        if !favourites.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Favourites")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)
                ], spacing: 12) {
                    ForEach(favourites) { channel in
                        // Wrapped as a single-channel group so it reuses the catalogue
                        // card — and because a group of one has no districts, tapping it
                        // plays rather than opening the picker.
                        GroupedChannelCard(
                            groupedChannel: GroupedChannel(channels: [channel]),
                            serviceManager: serviceManager,
                            onTap: onChannelTap,
                            cardWidth: 160,
                            cardHeight: 100
                        )
                        .id(channel.id)
                    }
                }
            }
        }
    }
}

struct DRChannelsSection: View {
    @ObservedObject var serviceManager: DRServiceManager
    let onChannelTap: (DRChannel) -> Void
    
    private var groupedChannels: [GroupedChannel] {
        GroupedChannel.grouped(from: serviceManager.availableChannels)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("DR")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primary)
                
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

    /// What VoiceOver announces for the card.
    ///
    /// The card's own text is a station name over artwork, sometimes with a district
    /// count — read out piecemeal that says very little. This states the station, what is
    /// on it now, and whether choosing it opens a district picker.
    private var accessibilitySummary: String {
        var parts = [groupedChannel.name]
        if let programme = serviceManager.getCurrentProgram(for: primaryChannel)?.cleanTitle(),
           !programme.isEmpty {
            parts.append(programme)
        }
        if groupedChannel.hasMultipleDistricts {
            // String(localized:) rather than plain interpolation: this string is assembled
            // into a Swift String, so unlike a Text it is not localised for us. The
            // catalog carries plural variants for it.
            parts.append(String(localized: "\(groupedChannel.channels.count) districts"))
        }
        return parts.joined(separator: ", ")
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint(groupedChannel.hasMultipleDistricts
                           ? "Choose a district"
                           : "Plays this channel")
        .contextMenu {
            // Only for a station that is one channel. Favouriting "P4" would be ambiguous —
            // it is ten district channels — so those are pinned from the district picker,
            // where you have said which one you mean.
            if !groupedChannel.hasMultipleDistricts {
                let channel = primaryChannel
                let isFavourite = serviceManager.userPreferences.isFavourite(channel.id)
                Button {
                    serviceManager.userPreferences.toggleFavourite(channel.id)
                } label: {
                    Label(isFavourite ? "Remove from Favourites" : "Add to Favourites",
                          systemImage: isFavourite ? "star.slash" : "star")
                }
            }
        }
        .sheet(isPresented: $showingDistrictSheet) {
            DistrictSelectionSheet(
                groupedChannel: groupedChannel,
                serviceManager: serviceManager,
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
                    .foregroundStyle(Color.primary)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.secondary)
                        .font(.system(size: 16))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Text(error)
                .font(.caption)
                .foregroundStyle(Color.secondary)
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
        selectionState: SelectionState()
    )
}
