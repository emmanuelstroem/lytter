//
//  StationNameTile.swift
//  lytter
//

import SwiftUI

/// A station drawn as its name: "P3", large, across the whole of its colour, with any detail
/// — the district, the programme — small beneath it, and the programme's picture, when there
/// is one, showing through the colour.
///
/// The name is the card, not a caption at its foot, so it reads from across a room, and every
/// card looks the same whether or not it has a picture: Show Images off, no artwork, or a
/// picture still loading all leave the plain colour, and the picture comes in beneath the
/// name when it arrives. The colours are DR's, the type is the system's: no DR artwork (S11).
/// The widgets' Favourites tiles are drawn the same way, without the picture.
struct StationNameTile: View {
    let name: String
    let stationKey: String
    var details: [String] = []
    /// The programme's picture, tinted with the station's colour (`StationTileArtwork`).
    var artworkURL: URL? = nil

    var body: some View {
        StationPalette.color(stationName: name, stationKey: stationKey)
            .overlay {
                if let artworkURL {
                    CachedAsyncImage(url: artworkURL,
                                     maxPixelSize: ImageCacheService.thumbnailMaxPixelSize) { image in
                        StationTileArtwork.tinted(image, stationName: name)
                    } placeholder: {
                        Color.clear
                    }
                    .accessibilityHidden(true)
                }
            }
            // The overlay is laid out at the colour's size, but a filled picture overflows it.
            .clipped()
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

/// How the programme's picture shows through a station's tile: in grey, blended into the
/// colour at part strength, and only ever away from the name's colour.
///
/// Under a white name the picture multiplies — it can only darken the colour; under a
/// near-black name it screens — it can only lighten it. Either way every pixel of the tile
/// is at least as far from the name's colour as the flat colour was, so the name reads on
/// any picture at least as well as it does on the plain tile, which `StationPaletteTests`
/// already holds to 3:1. A plain tint over the picture could not promise that: a white
/// patch of photograph under P2's white name would wash it out. In grey, the picture keeps
/// the station's hue rather than fighting it.
enum StationTileArtwork {
    /// How far the picture darkens the colour under a white name: 0 is the flat colour, 1
    /// black in the picture's shadows.
    nonisolated static let darkeningStrength: Double = 0.55
    /// How far it lightens the colour under a near-black name, towards white in its
    /// highlights. Less than the darkening, and with the picture's mid-tones pushed down
    /// first: a photograph is mostly mid-tones, and screened at full measure they turned
    /// P1's orange to peach and P3's green to mint across the whole tile.
    nonisolated static let lighteningStrength: Double = 0.45

    nonisolated static func lightens(stationName: String) -> Bool {
        StationPalette.hasDarkText(stationName: stationName)
    }

    nonisolated static func blendMode(stationName: String) -> BlendMode {
        lightens(stationName: stationName) ? .screen : .multiply
    }

    @ViewBuilder
    static func tinted(_ image: Image, stationName: String) -> some View {
        let grey = image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .grayscale(1)
        Group {
            if lightens(stationName: stationName) {
                grey
                    // Only the highlights are left to lighten the colour.
                    .contrast(1.4)
                    .brightness(-0.2)
                    .opacity(lighteningStrength)
            } else {
                grey
                    .opacity(darkeningStrength)
            }
        }
        .blendMode(blendMode(stationName: stationName))
    }
}

/// A station card's face: the station's `StationNameTile` — its name across its colour, with
/// the programme's picture showing through — and the accessory (the district picker's
/// chevron, the playing mark) in the bottom corner.
///
/// Shared by the phone's, the television's and the Mac's cards, so the three look alike. The
/// cards keep their own shapes, shadows and focus.
struct StationCardFace<Accessory: View>: View {
    let channel: DRChannel
    let artworkURL: URL?
    /// "P4", or "P4 - København" for a card that stands for one district.
    let title: String
    /// The programme, which a featured card carries beneath the name.
    var subtitle: String? = nil
    let metrics: StationCardMetrics
    @ViewBuilder var accessory: () -> Accessory

    /// The district, when the card is one, and on a featured card the programme too.
    private var tileDetails: [String] {
        var details: [String] = []
        if title != channel.name, let district = channel.district { details.append(district) }
        if metrics.style.captionsProgramme, let subtitle { details.append(subtitle) }
        return details
    }

    var body: some View {
        StationNameTile(name: channel.name, stationKey: channel.stationKey,
                        details: tileDetails, artworkURL: artworkURL)
            .frame(width: metrics.width, height: metrics.height)
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 4) { accessory() }
                    .foregroundStyle(StationPalette.textColor(stationName: channel.name))
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.vertical, metrics.verticalPadding)
            }
    }
}
