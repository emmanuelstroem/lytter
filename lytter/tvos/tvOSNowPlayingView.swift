//
//  tvOSNowPlayingView.swift
//  lytter
//
//  Created by Assistant on 08/08/2025.
//

import SwiftUI
#if canImport(GroupActivities)
import GroupActivities
#endif

// MARK: - Info Sheet
#if os(tvOS)
struct tvOSNowPlayingInfoSheet: View {
    let channel: DRChannel
    let program: DREpisode?
    let track: DRTrack?

    var body: some View {
        let descriptionText = program?.description
//            .replacingOccurrences(of: "\n\n", with: "\n")
//            .replacingOccurrences(of: "\n", with: "\n\n") // add spacing between paragraphs
            ?? "No description available."

        ZStack {
            VStack(alignment: .leading, spacing: 24) {
                if let title = program?.cleanTitle(), !title.isEmpty {
                    Text(title)
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                }

                ScrollView(showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Ensure long content is fully visible within scroll container
                        Text(descriptionText)
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.leading)
                            .lineSpacing(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .minimumScaleFactor(0.2)
                    }
                }
                Spacer(minLength: 0)
            }
//            .padding(EdgeInsets(top: 36, leading: 36, bottom: 36, trailing: 36))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                Group {
                    if #available(tvOS 17.0, *) {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.ultraThinMaterial)
                    } else {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.black.opacity(0.7))
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
//            .shadow(color: .black.opacity(0.35), radius: 22, x: 0, y: 10)
            .padding(40)
        }
    }
}
#endif

#if os(tvOS)
struct tvOSNowPlayingView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @State private var showingInfoSheet = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, .black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            if let channel = serviceManager.playingChannel {
                VStack(spacing: 40) {
                    tvOSNowPlayingArtwork(channel: channel)

                    // Live progress bar with centered LIVE label (visual only for live streams)
                    VStack(spacing: 8) {
                        GeometryReader { geometry in
                            ZStack {
                                ProgressView(value: 0.5, total: 1.0)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                    .scaleEffect(y: 2)
                                    .frame(maxWidth: .infinity)
                                    .mask(
                                        RadialGradient(
                                            colors: [
                                                Color.black.opacity(0.0),
                                                Color.black.opacity(0.5),
                                                Color.black.opacity(1.0)
                                            ],
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: geometry.size.width * 0.5 // 3/4 of half width
                                        )
                                    )

                                Text("LIVE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .opacity(0.8)
                            }
                        }
                        .frame(height: 20)
                        .padding(.horizontal, 20)
                    }

                    // Info and SharePlay actions
                    HStack {
                        Button(action: { showingInfoSheet = true }) {
                            Label("", systemImage: "info.circle")
                                .font(.title2)
                        }
                        
                        Spacer()

                        Button(action: {
                            if let channel = serviceManager.playingChannel {
                                startSharePlay(for: channel)
                            }
                        }) {
                            Label("", systemImage: "shareplay")
                                .font(.title2)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Playback is controlled exclusively via the tvOS remote
                }
                .padding(.horizontal, 80)
                .sheet(isPresented: $showingInfoSheet) {
                    if let channel = serviceManager.playingChannel {
                        tvOSNowPlayingInfoSheet(
                            channel: channel,
                            program: serviceManager.getCurrentProgram(for: channel),
                            track: serviceManager.currentTrack
                        )
                    }
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "play.circle").font(.system(size: 100)).foregroundColor(.white.opacity(0.9))
                    Text("Nothing Playing")
                        .font(.title)
                        .foregroundColor(.white)
                    if let first = serviceManager.availableChannels.first {
                        Button("Play \(first.title)") {
                            serviceManager.playChannel(first)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
}

#if canImport(GroupActivities)
@available(tvOS 15.0, *)
extension tvOSNowPlayingView {
    private func startSharePlay(for channel: DRChannel) {
        // Simple GroupActivity representing listening together to a channel
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
}
#endif

private struct tvOSNowPlayingArtwork: View {
    let channel: DRChannel
    @EnvironmentObject private var serviceManager: DRServiceManager

    var body: some View {
        let imageURL: URL? = {
            if let program = serviceManager.getCurrentProgram(for: channel), let url = program.landscapeImageURL ?? program.primaryImageURL { return URL(string: url) }
            return nil
        }()

        ZStack(alignment: .bottomLeading) {
            // Artwork with rounded corners
            Group {
                if let url = imageURL {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                } else {
                    LinearGradient(
                        colors: [.purple.opacity(0.7), .blue.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(maxWidth: 1200, maxHeight: 680)
            .clipped()

            // Bottom gradient overlay for text readability
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.6), Color.black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 160)
            .frame(maxWidth: .infinity, alignment: .bottom)
            .allowsHitTesting(false)

            // Text overlays with marquee
            VStack(alignment: .leading, spacing: 6) {
                MarqueeText(
                    text: channel.title,
                    font: .system(size: 42, weight: .bold),
                    leftFade: 16,
                    rightFade: 16,
                    startDelay: 1.0,
                    alignment: .leading
                )
                .foregroundColor(.white)

                if let program = serviceManager.getCurrentProgram(for: channel) {
                    MarqueeText(
                        text: program.cleanTitle(),
                        font: .system(size: 28, weight: .semibold),
                        leftFade: 16,
                        rightFade: 16,
                        startDelay: 1.5,
                        alignment: .leading
                    )
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.top, 10)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: 1200, maxHeight: 680)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .shadow(radius: 18)
    }
}
#endif

