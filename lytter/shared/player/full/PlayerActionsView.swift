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
    let onQuoteTap: (() -> Void)?
    let onAirPlayTap: (() -> Void)?
    let onListTap: (() -> Void)?
    
    init(
        showQuoteButton: Bool = true,
        showAirPlayButton: Bool = true,
        showListButton: Bool = true,
        onQuoteTap: (() -> Void)? = nil,
        onAirPlayTap: (() -> Void)? = nil,
        onListTap: (() -> Void)? = nil
    ) {
        self.showQuoteButton = showQuoteButton
        self.showAirPlayButton = showAirPlayButton
        self.showListButton = showListButton
        self.onQuoteTap = onQuoteTap
        self.onAirPlayTap = onAirPlayTap
        self.onListTap = onListTap
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
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
                
                if showAirPlayButton {
                    // Increase the size slightly to compensate for the AirPlay button's internal sizing
                    AirPlayButtonView(size: 24)
                        .foregroundColor(.gray)
                }
                Spacer()
                if showListButton {
                    Button(action: {
                        onListTap?()
                    }) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.3, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, geometry.size.width * 0.2)
        }
    }
}

#Preview {
    PlayerActionsView(
        onQuoteTap: { print("Info tapped") },
        onAirPlayTap: { print("AirPlay tapped") },
        onListTap: { print("List tapped") }
    )
} 
