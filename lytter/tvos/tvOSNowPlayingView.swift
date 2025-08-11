//
//  tvOSNowPlayingView.swift
//  lytter
//
//  Created by Assistant on 08/08/2025.
//

import SwiftUI

#if os(tvOS)
struct tvOSNowPlayingView: View {
    @ObservedObject var serviceManager: DRServiceManager

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

                    // Playback is controlled exclusively via the tvOS remote
                }
                .padding(.horizontal, 80)
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

