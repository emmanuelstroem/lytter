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
#endif
