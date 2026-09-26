//
//  CaptionBackdrop.swift
//  lytter
//

import SwiftUI

#if os(iOS) || os(tvOS)
/// Backdrop for a caption sitting on artwork.
///
/// Liquid Glass where the OS has it, an `.ultraThinMaterial` below that — the same shape
/// either way, so the layout does not shift across versions. Both refract what is behind
/// them, which is the point: a card's artwork is arbitrary photography and plain text on it
/// is unreadable often enough to matter.
///
/// Shared by iOS and tvOS. A station card should look like itself on every screen it appears
/// on, and two copies of a gradient drift apart the first time one of them is tuned.
struct CaptionBackdrop: View {

    /// How far above its solid part the glass starts to come in.
    ///
    /// The fade is a fixed length at the top, with full strength below it, rather than
    /// stretched over the whole backdrop. Stretched, the gradient was still at a third of
    /// its strength where the top of the name sat — and at a sixth behind the name on a
    /// featured card, which stacks the programme under it — so the artwork's own lettering
    /// showed through the station's name. Solid under the words, the backdrop is equally
    /// dark behind every line of the caption however many there are.
    let fadeLength: CGFloat

    var body: some View {
        glass
            .mask {
                GeometryReader { proxy in
                    fade(endingAt: fadeLength / max(proxy.size.height, 1))
                }
            }
            .allowsHitTesting(false)
    }

    /// Slow to start, then decisive, so the glass has no edge for the light to catch — a
    /// straight top edge on bright artwork read as a lit strip across the card.
    ///
    /// One gradient over the whole backdrop, holding full strength from `end` down, rather
    /// than a gradient stacked on a solid rectangle. Stacked, the two met at a hairline
    /// seam whenever the card was scaled — as tvOS does to the focused one — and the seam
    /// showed as a line across the glass.
    private func fade(endingAt end: CGFloat) -> LinearGradient {
        let end = min(end, 1)
        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.2), location: 0.35 * end),
                .init(color: .black.opacity(0.65), location: 0.7 * end),
                .init(color: .black, location: end)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// `clear` rather than `regular`: it is the variant meant to sit on media, more
    /// transparent and carrying its own dimming layer to keep whatever is on top legible.
    /// Regular glass frosted the artwork more than it needed to.
    ///
    /// The black tint is not decoration either. Clear glass alone did not dim enough — on
    /// pale artwork white text came out weaker than it had been under regular glass, and a
    /// subtitle over a bright photograph all but vanished. Tinting darkens the band by a
    /// fixed amount instead of leaving it to whatever is behind.
    /// How hard the glass is tinted.
    ///
    /// One number, in one place, because it is the dial that decides whether the station's
    /// name can be read. Clear glass alone does almost nothing over bright artwork — a
    /// yellow-and-white album cover left a white name barely visible — and the tint is what
    /// puts a floor under the contrast regardless of what is behind it.
    ///
    /// At 0.6 the artwork's own lettering still read through the glass — "P2 KONCERTEN"
    /// printed across the artwork sat legibly behind the name "P2".
    private static let tint = 0.75

    @ViewBuilder
    private var glass: some View {
        if #available(iOS 26.0, tvOS 26.0, *) {
            Rectangle().fill(.clear)
                .glassEffect(.clear.tint(.black.opacity(Self.tint)), in: .rect)
        } else {
            // The same tint, by hand. Before 26 there is no Liquid Glass, and an untinted
            // material is a flat bar rather than tinted glass — which is how the tvOS cards
            // came out when first checked on a tvOS 18 box. Tinting the fallback keeps the
            // band recognisably the same thing on an older system.
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(Self.tint))
        }
    }
}

extension View {

    /// Pins a caption that sits on artwork to the dark appearance.
    ///
    /// Glass has no automatic contrast against what it covers — `Glass` offers `regular`,
    /// `clear`, `tint` and `interactive`, and none of them adapt the text. So in light mode
    /// `.primary` resolved to black while the glass over a night photograph rendered dark,
    /// and the station's name disappeared into its own backdrop.
    ///
    /// Forcing the appearance fixes both halves at once: the glass renders its dark variant
    /// and `.primary` becomes white, so the caption is light-on-dark over any artwork in
    /// either theme. It is what Apple Music does — text laid on album art is white there
    /// whatever the system appearance. The card's own artwork is unaffected, and text
    /// outside the artwork still follows the app's theme.
    ///
    /// tvOS is always dark, so it changes nothing there — it is applied anyway so the two
    /// platforms build their cards from the same pieces.
    func captionOnArtwork() -> some View {
        environment(\.colorScheme, .dark)
    }
}
#endif
