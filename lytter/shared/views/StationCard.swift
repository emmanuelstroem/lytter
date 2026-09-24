//
//  StationCard.swift
//  lytter
//

import SwiftUI

#if os(iOS) || os(tvOS)
/// How prominent a card is.
///
/// Apple Music does this too: the top row is larger and captions its artwork, the rows below
/// are smaller and caption beneath. Two sizes is the whole hierarchy — a third would stop
/// reading as "this one matters more".
enum StationCardStyle {
    /// Large card. Station and programme both laid over the artwork, behind glass that fades
    /// in rather than starting at an edge.
    case featured
    /// Smaller card. Station on a band across the foot of the artwork, programme beneath the
    /// card on the page.
    case standard

    var fades: Bool { self == .featured }
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

    /// The caption occupies the bottom 40% of the card. The station's name is the thing
    /// being chosen, so it gets the room.
    var captionHeight: CGFloat { height * 0.40 }

    var nameFontSize: CGFloat { captionHeight * 0.45 }

    /// Small enough to stay a caption, but floored so it never falls below legible on the
    /// smallest card.
    var subtitleFontSize: CGFloat { max(11, nameFontSize * 0.34) }

    /// The fade reaches higher than the caption, so the glass arrives gradually instead of
    /// appearing to start just above the words.
    var fadeHeight: CGFloat { height * 0.52 }

    var horizontalPadding: CGFloat { width * 0.055 }
    var bottomPadding: CGFloat { height * 0.045 }

    // MARK: - The two platforms' cards

    static func iOS(_ style: StationCardStyle) -> StationCardMetrics {
        switch style {
        case .featured:
            return .init(width: 240, height: 280, cornerRadius: 14, style: style)
        case .standard:
            return .init(width: 148, height: 148, cornerRadius: 12, style: style)
        }
    }

    static func tvOS(_ style: StationCardStyle) -> StationCardMetrics {
        switch style {
        case .featured:
            return .init(width: 460, height: 460, cornerRadius: 22, style: style)
        case .standard:
            return .init(width: 300, height: 300, cornerRadius: 16, style: style)
        }
    }
}

/// How a station is drawn wherever it appears in a shelf or a grid.
///
/// The anatomy is shared because it is what makes a station recognisable: the name on glass
/// across the foot of the artwork, and — depending on the style — the programme either beside
/// it under the same glass or printed beneath the card on the page.
///
/// What is deliberately not shared is the assembly: focus behaviour, shadows and button
/// styles differ between a phone you touch and a television you point a remote at, and
/// forcing those together would mean a pile of platform flags inside one view. Anatomy is
/// common, ergonomics are local.
enum StationCard {

    /// The caption laid over the artwork.
    ///
    /// Artwork is arbitrary photography, so text on it is unreadable often enough to matter;
    /// the backdrop is not decoration. `featured` fades across the card and carries the
    /// programme too, `standard` is a band one caption deep that meets the image at a
    /// straight edge.
    struct Caption<Accessory: View>: View {
        let title: String
        var subtitle: String? = nil
        let metrics: StationCardMetrics
        @ViewBuilder var accessory: () -> Accessory

        var body: some View {
            VStack(alignment: .leading, spacing: metrics.height * 0.005) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: metrics.nameFontSize, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        // Shrinks rather than truncates. The station is the thing being
                        // chosen — "P4 Køben…" is a worse card than slightly smaller type.
                        .minimumScaleFactor(0.6)

                    accessory()
                }

                if let subtitle, metrics.style.captionsProgramme {
                    Text(subtitle)
                        .font(.system(size: metrics.subtitleFontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.bottom, metrics.bottomPadding)
            .frame(maxWidth: .infinity,
                   minHeight: metrics.captionHeight,
                   alignment: .bottomLeading)
            // The backdrop is sized independently of the text and laid behind it, so a fade
            // spans the card rather than the caption.
            .background(alignment: .bottom) {
                CaptionBackdrop(fades: metrics.style.fades)
                    .frame(height: metrics.style.fades ? metrics.fadeHeight
                                                       : metrics.captionHeight)
            }
            .captionOnArtwork()
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

        var body: some View {
            // Concrete rather than hierarchical: this sits on the background, not on a
            // material, and inside a Button hierarchical styles resolve against the tint.
            Text(text)
                .font(.system(size: metrics.subtitleFontSize))
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
                // A rounded card container clips text that starts flush at its edge —
                // "Orientering" came out as "rientering".
                .padding(.horizontal, 6)
        }
    }
}

extension StationCard.Caption where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil, metrics: StationCardMetrics) {
        self.init(title: title, subtitle: subtitle, metrics: metrics) { EmptyView() }
    }
}
#endif
