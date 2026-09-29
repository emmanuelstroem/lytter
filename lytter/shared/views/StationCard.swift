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

    /// Sized to the card's width, so that every station's name fits across it at the same
    /// size.
    ///
    /// It used to follow the card's height and shrink to fit, which made "P1" nearly twice
    /// the size of "P4 - Nordjylland" in the same row. The longest names DR broadcasts —
    /// "P4 - Nordjylland", "P5 - Midt & Vest" — measure about 7.9 times their point size in
    /// the bold system font, and the caption has 89% of the card to put them in. A tenth of
    /// the width fits them, and on a television leaves room for the playing marker beside
    /// them. `StationCardTests` measures both.
    var nameFontSize: CGFloat { width * 0.10 }

    /// Small enough to stay a caption, but floored so it never falls below legible on the
    /// smallest card.
    var subtitleFontSize: CGFloat { max(11, nameFontSize * 0.68) }

    /// The chevron, or the playing marker, beside the name.
    var accessoryFontSize: CGFloat { nameFontSize * 0.65 }

    /// How far the glass reaches above the caption on its way in.
    ///
    /// Only the fade. Under the words themselves the glass is at full strength, so how
    /// dark the text's backdrop is does not depend on how many lines the caption has.
    var fadeLength: CGFloat { height * 0.22 }

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
    /// the backdrop is not decoration. `featured` carries the programme too, `standard` only
    /// the name.
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
                        // No minimumScaleFactor. Shrinking to fit put "P1" and
                        // "P4 - Nordjylland" side by side at different sizes; the size is
                        // chosen so that every name DR broadcasts fits, and one that does not
                        // is truncated rather than set smaller than its neighbours.
                        .truncationMode(.tail)

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
            .padding(.vertical, metrics.verticalPadding)
            // Room for the fade above the words, inside the caption's own frame, so the
            // backdrop is simply the caption's background.
            .padding(.top, metrics.fadeLength)
            .frame(maxWidth: .infinity, alignment: .bottomLeading)
            // Full strength behind the words, fading in above them.
            .background {
                CaptionBackdrop(fadeLength: metrics.fadeLength)
            }
            .captionOnArtwork()
        }
    }

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
                // Hierarchical, not Color.secondary: this sits on the caption's glass.
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

        var body: some View {
            // Concrete rather than hierarchical: this sits on the background, not on a
            // material, and inside a Button hierarchical styles resolve against the tint.
            Text(text)
                .font(.system(size: metrics.subtitleFontSize))
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
                // A rounded card container clips text that starts flush at its edge —
                // "Orientering" came out as "rientering". Six points on the phone's card,
                // scaled with the card so the television's sits the same way.
                .padding(.horizontal, metrics.width * 0.04)
        }
    }
}

extension StationCard.Caption where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil, metrics: StationCardMetrics) {
        self.init(title: title, subtitle: subtitle, metrics: metrics) { EmptyView() }
    }
}
#endif
