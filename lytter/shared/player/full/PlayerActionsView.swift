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
                            .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.3, weight: .medium))
                            .foregroundStyle(Color.secondary)
                    }
                    .accessibilityLabel("Programme information")
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
                            .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.3, weight: .medium))
                            .foregroundStyle(Color.secondary)
                    }
                    .accessibilityLabel("Today's schedule")
                }
                Spacer()
                if showSleepButton {
                    let isRunning = sleepTimerMinutesRemaining != nil
                    Button(action: {
                        onSleepTap?()
                    }) {
                        Image(systemName: isRunning ? "moon.zzz.fill" : "moon.zzz")
                            .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.3, weight: .medium))
                            // Tinted while running: the only indication on this screen
                            // that playback is going to stop by itself.
                            .foregroundStyle(isRunning ? Color.accentColor : Color.secondary)
                    }
                    .accessibilityLabel("Sleep timer")
                    .accessibilityValue(
                        sleepTimerMinutesRemaining.map { String(localized: "\($0) minutes remaining") }
                            ?? String(localized: "Off")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, geometry.size.width * 0.12)
        }
    }
}

#Preview {
    PlayerActionsView(
        sleepTimerMinutesRemaining: 24,
        onQuoteTap: {},
        onListTap: {},
        onSleepTap: {}
    )
} 
