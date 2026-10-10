//
//  PlayerInfoView.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import SwiftUI

struct PlayerInfoView: View {
    let title: String
    let subtitle: String
    let channel: DRChannel?
    let serviceManager: DRServiceManager?
    
    @State private var shareImage: PlatformImage?
    
    init(
        title: String,
        subtitle: String,
        channel: DRChannel? = nil,
        serviceManager: DRServiceManager? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.channel = channel
        self.serviceManager = serviceManager
    }
    
    private var deepLinkURL: URL? {
        guard let channel = channel else { return nil }
        return DeepLinkHandler.generateDeepLinkURL(for: channel)
    }
    
    private var currentProgram: DREpisode? {
        guard let channel = channel, let serviceManager = serviceManager else { return nil }
        return serviceManager.getCurrentProgram(for: channel)
    }
    
    private var channelArtworkURL: URL? {
        guard let currentProgram = currentProgram,
              let imageURL = currentProgram.primaryImageURL else { return nil }
        return URL(string: imageURL)
    }
    
    private var channelDisplayName: String {
        guard let channel = channel else { return "" }
        
        var displayName = channel.name
        if let district = channel.district {
            displayName += " \(district)"
        }
        return displayName
    }
    
    private var shareText: String {
        var text = "🎵 \(title)"
        if !subtitle.isEmpty {
            text += "\n📻 \(subtitle)"
        }
        if !channelDisplayName.isEmpty {
            text += "\n📡 \(channelDisplayName)"
        }
        
        // Add deep link
        if let channel = channel {
            text += "\n🔗 \(DeepLinkHandler.generateDeepLinkString(for: channel))"
        }
        
        return text
    }
    
    var body: some View {
        // Sized by text styles, not by a share of a GeometryReader's frame as before, which
        // ignored Dynamic Type: at the largest sizes the station and track stayed small while
        // the progress row below them grew. The row now takes the height its text needs.
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                // A marquee, like the line under it. While a track plays the title is the
                // station *and* the programme, and as a one-line Text it was cut off with
                // an ellipsis — on a smaller iPhone, before the programme's name even began.
                MarqueeText(
                    text: title,
                    font: .headline,
                    leftFade: 16,
                    rightFade: 16,
                    startDelay: 1.5
                )
                .accessibilityID("player.title")
                .foregroundStyle(Color.primary)

                MarqueeText(
                    text: subtitle,
                    font: .subheadline,
                    leftFade: 16,
                    rightFade: 16,
                    startDelay: 1.5
                )
                .foregroundStyle(Color.secondary)
            }
            // The programme being heard can be pinned from here as well as from the
            // schedule (F33): the moment someone thinks "I like this" is while it plays.
            .contentShape(Rectangle())
            .contextMenu {
                if let currentProgram, let serviceManager {
                    FavouriteShowButton(episode: currentProgram,
                                        preferences: serviceManager.userPreferences)
                }
            }

            Spacer(minLength: 0)

            // A share button, not a menu. The menu had exactly one live item —
            // this same ShareLink — so it cost a tap for nothing.
            //
            // It shares a `SharedChannel`, which carries a SharePlay activity as well as
            // the text: that is what puts SharePlay at the top of the share sheet, as in
            // Music.
            #if os(iOS) || os(macOS) || os(visionOS)
            if let channel {
                ShareLink(
                    item: SharedChannel(activity: RadioShareActivity(channel: channel),
                                        text: shareText),
                    preview: sharePreview
                ) { shareLabel }
                .accessibilityLabel("Share")
            }
            #endif
        }
        .padding(.horizontal, 20)
        .onAppear {
            loadShareImage()
        }
    }
    
    #if os(iOS) || os(macOS) || os(visionOS)
    private var sharePreview: SharePreview<Image, Never> {
        SharePreview(
            title,
            image: shareImage.map { Image(platformImage: $0) } ?? Image(systemName: "music.note")
        )
    }

    private var shareLabel: some View {
        Image(systemName: "square.and.arrow.up.circle.fill")
            .font(.title2.weight(.medium))
            .foregroundStyle(Color.primary)
            .symbolRenderingMode(.hierarchical)
            // 44pt is the minimum comfortable target in the HIG.
            .frame(minWidth: 44, minHeight: 44)
    }
    #endif

    private func loadShareImage() {
        guard let artworkURL = channelArtworkURL else { return }
        
        ImageCacheService.shared.loadImage(from: artworkURL.absoluteString) { image in
            guard let image else { return }
            self.shareImage = image
        }
    }
}

#Preview {
    PlayerInfoView(
        title: "DR P1 - Morning Show",
        subtitle: "Current track information with long text that should scroll",
        channel: DRChannel(
            id: "p1",
            title: "DR P1",
            slug: "p1",
            type: "Channel",
            presentationUrl: "https://www.dr.dk/radio/p1"
        )
    )
} 
