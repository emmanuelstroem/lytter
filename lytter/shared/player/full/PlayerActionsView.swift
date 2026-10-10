//
//  PlayerActionsView.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import SwiftUI
import AVKit

struct PlayerActionsView: View {
    let showQuoteButton: Bool
    let showAirPlayButton: Bool
    let showListButton: Bool
    let showSleepButton: Bool
    /// Minutes left on the sleep timer, or nil when none is running.
    let sleepTimerMinutesRemaining: Int?
    let onQuoteTap: (() -> Void)?
    let onListTap: (() -> Void)?
    let onSleepTap: (() -> Void)?

    init(
        showQuoteButton: Bool = true,
        showAirPlayButton: Bool = true,
        showListButton: Bool = true,
        showSleepButton: Bool = true,
        sleepTimerMinutesRemaining: Int? = nil,
        onQuoteTap: (() -> Void)? = nil,
        onListTap: (() -> Void)? = nil,
        onSleepTap: (() -> Void)? = nil
    ) {
        self.showQuoteButton = showQuoteButton
        self.showAirPlayButton = showAirPlayButton
        self.showListButton = showListButton
        self.showSleepButton = showSleepButton
        self.sleepTimerMinutesRemaining = sleepTimerMinutesRemaining
        self.onQuoteTap = onQuoteTap
        self.onListTap = onListTap
        self.onSleepTap = onSleepTap
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: geometry.size.width * 0.06) {
                if showQuoteButton {
                    Button(action: {
                        onQuoteTap?()
                    }) {
                        Image(systemName: "info.circle")
                            .font(Self.glyphFont)
                            .foregroundStyle(Color.secondary)
                        // The target is the HIG's 44pt minimum, whatever the glyph's size.
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Programme information")
                    .accessibilityShowsLargeContentViewer {
                        Label("Programme information", systemImage: "info.circle")
                    }
                }
                Spacer()
                
                if showAirPlayButton {
                    // The same AirPlayButtonView the mini player uses — an
                    // AVRoutePickerView, which presents the route picker itself. There is
                    // deliberately no tap callback: there was one, and it was never
                    // invoked, which is why the full player's "AirPlay tapped" handler
                    // looked dead while the button actually worked.
                    // The tint is passed in rather than set with .foregroundColor: this
                    // wraps a UIKit view, so a SwiftUI foreground style never reached it —
                    // the old .gray here did nothing at all.
                    AirPlayButtonView(size: 24, tint: .secondaryLabel)
                }
                Spacer()
                if showListButton {
                    Button(action: {
                        onListTap?()
                    }) {
                        Image(systemName: "list.bullet")
                            .font(Self.glyphFont)
                            .foregroundStyle(Color.secondary)
                        // The target is the HIG's 44pt minimum, whatever the glyph's size.
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Today's schedule")
                    .accessibilityShowsLargeContentViewer {
                        Label("Today's schedule", systemImage: "list.bullet")
                    }
                }
                Spacer()
                if showSleepButton {
                    let isRunning = sleepTimerMinutesRemaining != nil
                    Button(action: {
                        onSleepTap?()
                    }) {
                        Image(systemName: isRunning ? "moon.zzz.fill" : "moon.zzz")
                            .font(Self.glyphFont)
                            // Tinted while running: the only indication on this screen
                            // that playback is going to stop by itself.
                            .foregroundStyle(isRunning ? Color.accentColor : Color.secondary)
                        // The target is the HIG's 44pt minimum, whatever the glyph's size.
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Sleep timer")
                    .accessibilityShowsLargeContentViewer {
                        Label("Sleep timer", systemImage: isRunning ? "moon.zzz.fill" : "moon.zzz")
                    }
                    .accessibilityIdentifier("player.sleep")
                    .accessibilityValue(
                        sleepTimerMinutesRemaining.map { String(localized: "\($0) minutes remaining") }
                            ?? String(localized: "Off")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, geometry.size.width * 0.12)
            // The glyphs follow Dynamic Type, as far as the first accessibility size: there
            // they are 28pt, the row's height less a margin, and the text above has the
            // screen's height to grow into where this row has its own. Past that, touch
            // and hold shows each control enlarged. Not AirPlay: AVRoutePickerView draws its
            // own glyph, at one size whatever its frame.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
    }

    /// The body text's style, 17pt by default: the size these glyphs were drawn at when
    /// they were a share of the row's height, which left them as they were at every
    /// text size.
    private static let glyphFont = Font.body.weight(.medium)
}

#Preview {
    PlayerActionsView(
        sleepTimerMinutesRemaining: 24,
        onQuoteTap: {},
        onListTap: {},
        onSleepTap: {}
    )
} 
