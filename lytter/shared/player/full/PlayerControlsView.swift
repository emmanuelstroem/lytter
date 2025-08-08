//
//  PlayerControlsView.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import SwiftUI

struct PlayerControlsView: View {
    let isPlaying: Bool
    let showBackwardButton: Bool
    let showPlayPauseButton: Bool
    let showForwardButton: Bool
    let onBackwardTap: (() -> Void)?
    let onPlayPauseTap: (() -> Void)?
    let onForwardTap: (() -> Void)?
    
    init(
        isPlaying: Bool,
        showBackwardButton: Bool = true,
        showPlayPauseButton: Bool = true,
        showForwardButton: Bool = true,
        onBackwardTap: (() -> Void)? = nil,
        onPlayPauseTap: (() -> Void)? = nil,
        onForwardTap: (() -> Void)? = nil
    ) {
        self.isPlaying = isPlaying
        self.showBackwardButton = showBackwardButton
        self.showPlayPauseButton = showPlayPauseButton
        self.showForwardButton = showForwardButton
        self.onBackwardTap = onBackwardTap
        self.onPlayPauseTap = onPlayPauseTap
        self.onForwardTap = onForwardTap
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 24) {
                HStack(spacing: geometry.size.width * 0.1) {
                    if showBackwardButton {
                        Button(action: {
                            onBackwardTap?()
                        }) {
                            Image(systemName: "gobackward.30")
                                .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.3, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if showPlayPauseButton {
                        Button(action: {
                            onPlayPauseTap?()
                        }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.8, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    if showForwardButton {
                        Button(action: {
                            onForwardTap?()
                        }) {
                            Image(systemName: "goforward.plus")
                                .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.3, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, geometry.size.width * 0.05)
        }
    }
}

#Preview {
    PlayerControlsView(
        isPlaying: false,
        onBackwardTap: { print("Backward tapped") },
        onPlayPauseTap: { print("Play/Pause tapped") },
        onForwardTap: { print("Forward tapped") }
    )
} 
