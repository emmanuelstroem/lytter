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

                    VStack(spacing: 8) {
                        Text(channel.title)
                            .font(.title)
                            .foregroundColor(.white)
                        if let program = serviceManager.getCurrentProgram(for: channel) {
                            Text(program.cleanTitle())
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        if let track = serviceManager.currentTrack, track.isCurrentlyPlaying {
                            Text(track.displayText)
                                .font(.callout)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    HStack(spacing: 40) {
                        Button(action: { serviceManager.togglePlayback(for: channel) }) {
                            Label(serviceManager.isPlaying ? "Pause" : "Play", systemImage: serviceManager.isPlaying ? "pause.fill" : "play.fill")
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: { serviceManager.stopPlayback() }) {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                    }
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

        ZStack {
            if let url = imageURL {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 30).fill(.gray.opacity(0.2))
                }
            } else {
                RoundedRectangle(cornerRadius: 30)
                    .fill(LinearGradient(colors: [.purple.opacity(0.7), .blue.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay {
                        Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 120)).foregroundColor(.white)
                    }
            }
        }
        .frame(maxWidth: 1200, maxHeight: 680)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .shadow(radius: 18)
    }
}
#endif

