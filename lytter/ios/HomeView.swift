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
    /// Observed directly: a nested ObservableObject does not republish through its owner,
    /// so pinning a channel would update the store and redraw nothing. That cost a debug
    /// cycle in #26.
    @ObservedObject var preferences: UserPreferencesService
    
    /// Wraps plain channels as single-channel groups, so the shelf can take one type.
    /// A group of one has no districts, so tapping it plays rather than opening a picker.
    private func singles(_ channels: [DRChannel]) -> [GroupedChannel] {
        channels.map { GroupedChannel(channels: [$0]) }
    }

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
                        let play: (DRChannel) -> Void = { channel in
                            serviceManager.playChannel(channel)
                            selectionState.selectChannel(channel, showSheet: false)
                        }

                        // Favourites, then history, then one shelf per broadcaster. Each
                        // draws nothing when it has nothing, so a first launch shows only
                        // the catalogue rather than two empty headings.
                        ChannelShelf(
                            title: String(localized: "Favourites"),
                            groups: singles(preferences.favourites.resolve(in: serviceManager.availableChannels)),
                            style: .featured,
                            serviceManager: serviceManager,
                            onChannelTap: play
                        )

                        ChannelShelf(
                            title: String(localized: "Recently Played"),
                            groups: singles(preferences.recentlyPlayed.resolve(in: serviceManager.availableChannels)),
                            serviceManager: serviceManager,
                            onChannelTap: play
                        )

                        ForEach(serviceManager.broadcasterSections) { section in
                            ChannelShelf(
                                title: section.broadcaster.name,
                                groups: GroupedChannel.grouped(from: section.channels),
                                serviceManager: serviceManager,
                                onChannelTap: play
                            )
                        }
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

            // A sibling of the background rather than an overlay on the scroll view: as an
            // overlay it inherits the scroll view's already-inset frame, so it drew an
            // 18-point band below the status bar instead of behind it.
            StatusBarScrim()
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
    let manager = DRServiceManager()
    HomeView(
        serviceManager: manager,
        selectionState: SelectionState(),
        preferences: manager.userPreferences
    )
}
