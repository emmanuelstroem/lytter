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

    /// Whether the glass fades in over the artwork or meets it at a straight edge.
    ///
    /// A large card fades: its caption sits well inside the image, and a hard line across the
    /// middle would cut the artwork in two. A small card does not — the band is one line of
    /// text deep and sits on the very edge, where a straight edge reads as a label laid on
    /// the artwork rather than as a seam through it.
    let fades: Bool

    var body: some View {
        Group {
            if fades { glass.mask(fade) } else { glass }
        }
        .allowsHitTesting(false)
    }

    /// Slow to start, then decisive. The frost stays out of the way over the upper part of
    /// the card and only reaches full strength where the text actually sits, so the artwork
    /// reads as itself rather than as something behind fog.
    private var fade: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.18), location: 0.34),
                .init(color: .black.opacity(0.55), location: 0.62),
                .init(color: .black.opacity(0.92), location: 0.84),
                .init(color: .black, location: 1)
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
    private static let tint = 0.6

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
