//
//  StationNameTile.swift
//  lytter
//

import SwiftUI

/// A station drawn as its name: "P3", large, across the whole of its colour, with any detail
/// — the district, the programme — small beneath it.
///
/// What a card shows when it has no picture: Show Images is off, or the station has no
/// artwork. The name is the card then, not a caption at its foot, because nothing else is
/// there to look at and a name that fills the card reads from across a room. The colours
/// are DR's, the type is the system's: no DR artwork (S11). The widgets' Favourites tiles
/// are drawn the same way.
struct StationNameTile: View {
    let name: String
    let stationKey: String
    var details: [String] = []

    var body: some View {
        StationPalette.color(stationName: name, stationKey: stationKey)
            .overlay {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    VStack(spacing: width * 0.02) {
                        // The station's own name: a proper noun, not for the catalogue.
                        Text(verbatim: name)
                            .stationTileName(width: width)
                        ForEach(details, id: \.self) { detail in
                            Text(verbatim: detail)
                                .font(.system(size: max(11, width * 0.085), weight: .semibold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                    .foregroundStyle(StationPalette.textColor(stationName: name))
                    .padding(width * StationTileType.paddingShare)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
    }
}

/// A station card's face: the programme's artwork with the caption on glass over its foot,
/// or — with no picture to show — the station's `StationNameTile`, which needs no caption
/// because it is the name. The accessory (the district picker's chevron, the playing mark)
/// sits in the caption with artwork, and in the tile's bottom corner without.
///
/// Shared by the phone's, the television's and the Mac's cards, so the three make the same
/// choice. The cards keep their own shapes, shadows and focus.
struct StationCardFace<Accessory: View>: View {
    let channel: DRChannel
    let artworkURL: URL?
    /// "P4", or "P4 - København" for a card that stands for one district.
    let title: String
    /// The programme, which a featured card carries in its caption.
    var subtitle: String? = nil
    let metrics: StationCardMetrics
    @ViewBuilder var accessory: () -> Accessory

    @Environment(\.showsArtwork) private var showsArtwork

    /// The district, when the card is one, and on a featured card the programme too.
    private var tileDetails: [String] {
        var details: [String] = []
        if title != channel.name, let district = channel.district { details.append(district) }
        if metrics.style.captionsProgramme, let subtitle { details.append(subtitle) }
        return details
    }

    var body: some View {
        if showsArtwork, artworkURL != nil {
            CachedAsyncImage(url: artworkURL,
                             maxPixelSize: ImageCacheService.thumbnailMaxPixelSize) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                // Only while the picture loads; the caption already names the station.
                StationArtworkPlaceholder(channel: channel, showsName: false)
            }
            .frame(width: metrics.width, height: metrics.height)
            .clipped()
            .overlay(alignment: .bottom) {
                StationCard.Caption(title: title, subtitle: subtitle, metrics: metrics,
                                    accessory: accessory)
            }
        } else {
            StationNameTile(name: channel.name, stationKey: channel.stationKey,
                            details: tileDetails)
                .frame(width: metrics.width, height: metrics.height)
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: 4) { accessory() }
                        .foregroundStyle(StationPalette.textColor(stationName: channel.name))
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.vertical, metrics.verticalPadding)
                }
        }
    }
}
