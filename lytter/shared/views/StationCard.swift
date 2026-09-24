//
//  StationCard.swift
//  lytter
//

import SwiftUI

#if os(iOS) || os(tvOS)
/// How a station is drawn wherever it appears in a shelf or a grid.
///
/// Two pieces, and both are shared because both are what makes a station recognisable:
/// the name on a band of glass across the foot of the artwork, and what is on it now printed
/// underneath — *outside* the card, on the page.
///
/// What is deliberately not shared is the assembly: sizes, focus behaviour, shadows and
/// button styles differ between a phone you touch and a television you point a remote at, and
/// forcing those together would mean a pile of platform flags inside one view. The rule is
/// that the anatomy is common and the ergonomics are local.
enum StationCard {

    /// The band across the foot of the artwork.
    ///
    /// Artwork is arbitrary photography, so text laid straight onto it is unreadable often
    /// enough to matter. `fades` picks between a gradient that spans the card and a band one
    /// line deep that meets the image at a straight edge.
    struct NameBand: View {
        let title: String
        var font: Font = .title2.weight(.bold)
        var horizontalPadding: CGFloat = 10
        var verticalPadding: CGFloat = 7
        var fades: Bool = false

        var body: some View {
            Text(title)
                .font(font)
                .foregroundStyle(.primary)
                .lineLimit(1)
                // Shrinks rather than truncates. The station is the thing being chosen —
                // "P4 Køben…" is a worse card than slightly smaller type.
                .minimumScaleFactor(0.7)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { CaptionBackdrop(fades: fades) }
                .captionOnArtwork()
        }
    }

    /// What is on the station now, printed beneath the card.
    ///
    /// Outside the artwork on purpose. Over the image it needs a scrim to be legible and
    /// competes with the name; on the page it needs nothing and simply reads. It also has to
    /// sit outside whatever button wraps the card — on tvOS the card button style draws a
    /// container around its whole label, and a subtitle inside that ends up boxed in with
    /// the artwork instead of printed under it.
    struct Subtitle: View {
        let text: String
        var font: Font = .caption

        var body: some View {
            // Concrete rather than hierarchical: this sits on the background, not on a
            // material, and inside a Button hierarchical styles resolve against the tint.
            Text(text)
                .font(font)
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
                // The rounded container a card button style draws clips text that starts
                // flush at its edge — "Orientering" came out as "rientering".
                .padding(.horizontal, 6)
        }
    }
}
#endif
