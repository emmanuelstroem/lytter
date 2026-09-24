//
//  AppBackground.swift
//  lytter
//

import SwiftUI

#if os(iOS)
/// The page background shared by every iOS screen.
///
/// Home, Radio, Search and the full player each carried their own copy of the same
/// three-stop `Color.black` gradient. Four copies meant the app ignored the system
/// appearance, and that every screen had to be found and fixed separately — which is
/// how the full player came to be the only one that adapted.
///
/// Semantically this is the same gradient: `systemBackground` is black in dark mode, so
/// dark mode looks as it always did. In light mode it is white, shading to the grey of
/// `secondarySystemBackground`.
struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.secondarySystemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// Keeps the clock and battery readable when content scrolls beneath them.
///
/// Home has no navigation bar — it was removed because it contributed an empty bar and
/// nothing else — so nothing stood between the status bar and the artwork passing behind
/// it. A bright card sliding under the time left it unreadable.
///
/// A gradient of the page background rather than a bar: a hard edge across the top would
/// read as a navigation bar that does nothing, which is what was removed in the first
/// place. This fades out before the content starts.
struct StatusBarScrim: View {

    /// Tall enough to cover the status bar on any iPhone and fade out below it.
    ///
    /// Fixed rather than measured. The shape is a fade, so being too tall merely finishes
    /// lower down, where being too short leaves the clock exposed — the failure modes are
    /// not symmetric. Measuring wanted the top safe-area inset, and a `GeometryReader`
    /// inside the screen's own stack reports that as zero: the inset has been consumed by
    /// the time the scrim can ask for it, which collapsed this to 18 points and made the
    /// whole thing look like it was not drawing at all.
    private let height: CGFloat = 110

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color(.systemBackground), location: 0),
                .init(color: Color(.systemBackground).opacity(0.85), location: 0.45),
                .init(color: Color(.systemBackground).opacity(0), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}

#endif
