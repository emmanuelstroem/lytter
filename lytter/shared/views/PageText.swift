//
//  PageText.swift
//  lytter
//

import SwiftUI

extension Color {
    /// Secondary text set directly on the page or the player sheet.
    ///
    /// `Color.secondary` is drawn at 60% opacity, which on the page's gradient (black to
    /// #1C1C1E in dark mode) and the lighter player sheet sits at or under the 4.5:1 contrast
    /// small text needs; the accessibility audit failed every programme line and the
    /// player's times on it. This is the same primary colour at a higher opacity: still
    /// clearly secondary beside primary text, but readable. Concrete rather than
    /// hierarchical — see AGENTS.md: a hierarchical style inside a Button resolves against
    /// the tint. On a material, keep using the hierarchical styles.
    static let secondaryOnPage = Color.primary.opacity(0.75)
}
