//
//  StationCard.swift
//  lytter
//

import SwiftUI

#if os(iOS) || os(tvOS) || os(macOS) || os(visionOS)
/// How prominent a card is.
///
/// Apple Music does this too: the top row is larger and captions its artwork, the rows below
/// are smaller and caption beneath. Two sizes is the whole hierarchy — a third would stop
/// reading as "this one matters more".
enum StationCardStyle {
    /// Large card. Station and programme both laid over the artwork.
    case featured
    /// Smaller card. Station over the artwork, programme beneath the card on the page.
    case standard

    /// Whether the programme is part of the caption or printed under the card.
    var captionsProgramme: Bool { self == .featured }
}

/// One platform's card sizes, and everything that follows from them.
///
/// Type is derived rather than fixed. The same design then holds from a 148-point shelf card
/// on a phone to a 460-point one on a television, instead of each platform carrying its own
/// hand-picked point sizes that drift apart the first time either is tuned.
struct StationCardMetrics {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let style: StationCardStyle

    /// The card's base type size, a tenth of its width, which the line beneath the card and
    /// the marks in its corner are sized from, so they keep their proportion from a phone's
    /// card to a television's. It was the size of the station's name in the caption across
    /// the card's foot; the name is the tile's now (`StationNameTile`), sized to the tile.
    var nameFontSize: CGFloat { width * 0.10 }

    /// Small enough to stay a caption, but floored so it never falls below legible on the
    /// smallest card.
    var subtitleFontSize: CGFloat { max(11, nameFontSize * 0.68) }

    /// The chevron, or the playing marker, in the card's corner.
    var accessoryFontSize: CGFloat { nameFontSize * 0.65 }

    var horizontalPadding: CGFloat { width * 0.055 }
    var verticalPadding: CGFloat { height * 0.045 }

    // MARK: - The two platforms' cards

    static func iOS(_ style: StationCardStyle) -> StationCardMetrics {
        switch style {
        case .featured:
            return .init(width: 240, height: 280, cornerRadius: 14, style: style)
        case .standard:
            return .init(width: 148, height: 148, cornerRadius: 12, style: style)
        }
    }

    /// The phone's proportions, scaled up: a featured card is taller than it is wide on
    /// both, so the two platforms' shelves are the same design rather than two similar ones.
    static func tvOS(_ style: StationCardStyle) -> StationCardMetrics {
        switch style {
        case .featured:
            return .init(width: 420, height: 490, cornerRadius: 22, style: style)
        case .standard:
            return .init(width: 300, height: 300, cornerRadius: 16, style: style)
        }
    }

    /// Between the phone and the television: a mouse is more precise than a finger but the
    /// window is smaller than a TV, so the cards land close to the iPad-sized end of the
    /// phone's own proportions rather than needing a third design.
    static func macOS(_ style: StationCardStyle) -> StationCardMetrics {
        switch style {
        case .featured:
            return .init(width: 220, height: 260, cornerRadius: 10, style: style)
        case .standard:
            return .init(width: 160, height: 160, cornerRadius: 8, style: style)
        }
    }
}

/// How a station is drawn wherever it appears in a shelf or a grid.
///
/// The anatomy is shared because it is what makes a station recognisable: the station's tile
/// (`StationCardFace`), its name across its colour, and — depending on the style — the
/// programme either on the tile beneath the name or printed beneath the card on the page.
///
/// What is deliberately not shared is the assembly: focus behaviour, shadows and button
/// styles differ between a phone you touch and a television you point a remote at, and
/// forcing those together would mean a pile of platform flags inside one view. Anatomy is
/// common, ergonomics are local.
enum StationCard {

    /// The cue that a card asks rather than plays: a station with districts, and no region
    /// chosen yet.
    ///
    /// Shared because a remote's click opens the same question a tap does, so the card
    /// needs to say so on both.
    struct PickerCue: View {
        let metrics: StationCardMetrics

        var body: some View {
            Image(systemName: "chevron.right")
                .font(.system(size: metrics.accessoryFontSize, weight: .bold))
                // Hierarchical, not Color.secondary: the card sets the tile name's colour
                // around it, and this is that colour a level down.
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    /// What is on the station now, printed beneath the card.
    ///
    /// Outside the artwork on purpose, for `standard` cards. Over the image it needs a scrim
    /// to be legible and competes with the name; on the page it needs nothing and simply
    /// reads.
    struct Subtitle: View {
        let text: String
        let metrics: StationCardMetrics
        /// Leads the line with the playing marker, for a card whose name has no room for it
        /// beside it (the Mac's standard card, F44).
        var showsPlayingMarker = false
        /// Dynamic Type for the line under the card. The size is still the card's — the
        /// television's card is larger — scaled by the reader's text size; tvOS has no
        /// Dynamic Type, so this stays 1 there. The name on the artwork does not scale: it
        /// sits in a fixed card, sized so that every name DR broadcasts fits.
        @ScaledMetric(relativeTo: .caption2) private var textScale: CGFloat = 1
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize

        var body: some View {
            // Concrete rather than hierarchical: this sits on the background, not on a
            // material, and inside a Button hierarchical styles resolve against the tint.
            HStack(spacing: 4) {
                if showsPlayingMarker {
                    PlayingMark()
                }
                #if os(tvOS)
                // Two lines, and room for two under every card so that a row's cards stay
                // level: at the television's reading size one line held too little of a
                // programme's name.
                Text(text)
                    .lineLimit(2, reservesSpace: true)
                #else
                Text(text)
                    // One line, as Music's captions are. At the accessibility sizes a line
                    // under a phone's card holds a word of a programme's name, if that —
                    // "Fixtur…" — so there it wraps, as far as three lines.
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                #endif
            }
            #if os(tvOS)
            // The platform's reading size. Derived from the card like the name, it came to
            // 20 points, below the system's own caption size, and read as small print from
            // across a room.
            .font(.body)
            #else
            .font(.system(size: metrics.subtitleFontSize * textScale))
            #endif
            .foregroundStyle(Color.secondaryOnPage)
                // A rounded card container clips text that starts flush at its edge —
                // "Orientering" came out as "rientering". Six points on the phone's card,
                // scaled with the card so the television's sits the same way.
                .padding(.horizontal, metrics.width * 0.04)
        }
    }
}
#endif
