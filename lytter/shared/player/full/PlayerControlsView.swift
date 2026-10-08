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
    /// False at the live edge, where there is nothing ahead to skip to.
    let isForwardEnabled: Bool
    /// Shown when set: a "Live" control that jumps to the live edge.
    let onLiveTap: (() -> Void)?
    let isBehindLive: Bool
    
    init(
        isPlaying: Bool,
        showBackwardButton: Bool = true,
        showPlayPauseButton: Bool = true,
        showForwardButton: Bool = true,
        onBackwardTap: (() -> Void)? = nil,
        onPlayPauseTap: (() -> Void)? = nil,
        onForwardTap: (() -> Void)? = nil,
        isForwardEnabled: Bool = true,
        onLiveTap: (() -> Void)? = nil,
        isBehindLive: Bool = false
    ) {
        self.isPlaying = isPlaying
        self.showBackwardButton = showBackwardButton
        self.showPlayPauseButton = showPlayPauseButton
        self.showForwardButton = showForwardButton
        self.onBackwardTap = onBackwardTap
        self.onPlayPauseTap = onPlayPauseTap
        self.onForwardTap = onForwardTap
        self.isForwardEnabled = isForwardEnabled
        self.onLiveTap = onLiveTap
        self.isBehindLive = isBehindLive
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 24) {
                HStack(spacing: geometry.size.width * 0.1) {
                    if showBackwardButton {
                        Button(action: {
                            onBackwardTap?()
                        }) {
                            Image(systemName: "gobackward.15")
                                .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.3, weight: .medium))
                                .foregroundStyle(Color.secondary)
                        }
                        .accessibilityLabel("Skip back 15 seconds")
                        .transportButtonStyle()
                    }
                    
                    if showPlayPauseButton {
                        Button(action: {
                            onPlayPauseTap?()
                        }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.8, weight: .medium))
                                .foregroundStyle(Color.primary)
                        }
                        // The label has to track the action, not the glyph: VoiceOver
                        // announces what the button will do.
                        .accessibilityLabel(isPlaying ? "Pause" : "Play")
                        .transportButtonStyle()
                    }
                    
                    if showForwardButton {
                        Button(action: {
                            onForwardTap?()
                        }) {
                            Image(systemName: "goforward.15")
                                .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.3, weight: .medium))
                                .foregroundStyle(Color.secondary)
                        }
                        .disabled(!isForwardEnabled)
                        .transportButtonStyle()
                        .opacity(isForwardEnabled ? 1 : 0.35)
                        .accessibilityLabel("Skip forward 15 seconds")
                    }
                }

                if let onLiveTap {
                    // Red while at the live edge; behind it, a tappable way back.
                    Button(action: onLiveTap) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isBehindLive ? Color.secondary : Color.red)
                                .frame(width: 8, height: 8)
                            Text("Live")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isBehindLive ? Color.primary : Color.red)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.secondary.opacity(isBehindLive ? 0.2 : 0)))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isBehindLive)
                    .accessibilityLabel(isBehindLive ? "Jump to live" : "Live")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, geometry.size.width * 0.05)
        }
    }
}

private extension View {
    /// No platter on visionOS. A button there draws a glass capsule by default, padded
    /// around its label; the glyphs here are sized from the row's height, and the play
    /// glyph spilled out of its capsule. Borderless keeps the gaze highlight, which takes
    /// the circle.
    @ViewBuilder
    func transportButtonStyle() -> some View {
        #if os(visionOS)
        buttonStyle(.borderless)
            .buttonBorderShape(.circle)
        #else
        self
        #endif
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
