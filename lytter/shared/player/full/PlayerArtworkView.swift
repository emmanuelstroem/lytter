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
    
    init(
        channel: DRChannel?,
        currentProgram: DREpisode?,
        channelColor: Color
    ) {
        self.channel = channel
        self.currentProgram = currentProgram
        self.channelColor = channelColor
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
    
    /// With no programme picture: the station's name across its colour, as every card
    /// draws a station with no picture — nothing else, so it reads at a glance.
    private var placeholderView: some View {
        GeometryReader { geometry in
            Group {
                if let channel {
                    StationNameTile(name: channel.name, stationKey: channel.stationKey)
                } else {
                    channelColor
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: min(geometry.size.width, geometry.size.height) * 0.05))
        }
    }
}

#Preview {
    PlayerArtworkView(
        channel: DRChannel(id: "p1", title: "DR P1", slug: "p1", type: "radio", presentationUrl: nil),
        currentProgram: nil,
        channelColor: .purple
    )
    .frame(width: 300, height: 300)
} 