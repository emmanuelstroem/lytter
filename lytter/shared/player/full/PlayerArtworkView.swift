//
//  PlayerArtworkView.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import SwiftUI

struct PlayerArtworkView: View {
    let channel: DRChannel?
    let currentProgram: DREpisode?
    let channelColor: Color
    let channelIcon: String
    
    init(
        channel: DRChannel?,
        currentProgram: DREpisode?,
        channelColor: Color,
        channelIcon: String
    ) {
        self.channel = channel
        self.currentProgram = currentProgram
        self.channelColor = channelColor
        self.channelIcon = channelIcon
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: geometry.size.height * 0.05) {
                if let currentProgram = currentProgram,
                   let imageURL = currentProgram.primaryImageURL,
                   let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        placeholderView
                    }
                    .frame(width: min(geometry.size.width, geometry.size.height) * 0.8, 
                           height: min(geometry.size.width, geometry.size.height) * 0.8)
                    .clipShape(RoundedRectangle(cornerRadius: min(geometry.size.width, geometry.size.height) * 0.05))
                    .shadow(radius: min(geometry.size.width, geometry.size.height) * 0.05)
                } else {
                    placeholderView
                        .frame(width: min(geometry.size.width, geometry.size.height) * 0.8, 
                               height: min(geometry.size.width, geometry.size.height) * 0.8)
                        .shadow(radius: min(geometry.size.width, geometry.size.height) * 0.05)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private var placeholderView: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: min(geometry.size.width, geometry.size.height) * 0.05)
                .fill(
                    LinearGradient(
                        colors: [
                            channelColor.opacity(0.9),
                            channelColor.opacity(0.7),
                            channelColor.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    VStack(spacing: min(geometry.size.width, geometry.size.height) * 0.04) {
                        Image(systemName: channelIcon)
                            .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.2, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text(channel?.title ?? "Unknown Channel")
                            .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.08, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                }
        }
    }
}

#Preview {
    PlayerArtworkView(
        channel: DRChannel(id: "p1", title: "DR P1", slug: "p1", type: "radio", presentationUrl: nil),
        currentProgram: nil,
        channelColor: .purple,
        channelIcon: "antenna.radiowaves.left.and.right"
    )
    .frame(width: 300, height: 300)
} 