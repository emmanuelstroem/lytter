//
//  HoverEffect.swift
//  lytter
//

import SwiftUI

extension View {
    /// The highlight a card shows on visionOS while someone looks at it.
    ///
    /// A plain-styled button highlights its whole frame as a rectangle, so a rounded card
    /// lit up with square corners around it. Shaped here with the card's own radius, the
    /// highlight follows the card's curve: the two shapes meet the same corner, so they
    /// share it (AGENTS.md, concentricity).
    ///
    /// Nothing elsewhere. A pointer or a finger has no gaze to answer, and on tvOS focus does
    /// this job its own way.
    @ViewBuilder
    func cardHoverEffect(cornerRadius: CGFloat) -> some View {
        #if os(visionOS)
        contentShape(.hoverEffect, RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .hoverEffect(.highlight)
        #else
        self
        #endif
    }
}
