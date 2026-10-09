//
//  StationArtworkPlaceholder.swift
//  lytter
//

import SwiftUI

extension EnvironmentValues {
    /// Whether programme artwork is drawn, from the Show Images setting (F43).
    ///
    /// An environment value rather than a check at every call site: `CachedAsyncImage`
    /// reads it, so every picture in the app obeys the setting without each screen having
    /// to observe `UserPreferencesService` itself. `PreferencesEnvironment` sets it.
    @Entry var showsArtwork = true
}

/// Puts the listener's display preferences into the environment.
///
/// A modifier observing `UserPreferencesService` directly: reaching it through
/// `DRServiceManager` would not redraw when it changes (see AGENTS.md).
struct PreferencesEnvironment: ViewModifier {
    @ObservedObject var preferences: UserPreferencesService

    func body(content: Content) -> some View {
        content.environment(\.showsArtwork, preferences.showsArtwork)
    }
}

extension DRChannel {
    /// A colour for the station, which stands in for its artwork when there is none. Shared
    /// with the widgets through `StationPalette`, which says how it is chosen.
    var stationColor: Color {
        StationPalette.color(stationName: name, stationKey: stationKey)
    }
}

/// The station's colour, and optionally its name, in place of a picture.
///
/// What every artwork slot shows with Show Images off, and while a picture is loading. The
/// name is left off where a caption already says it — on a shelf card it would be printed
/// twice. With the name it is the station's `StationNameTile`.
///
/// Flat, as DR's colours are: the name's colour is chosen for contrast against the colour
/// itself, and a gradient towards transparent would darken it on a dark background — P4's
/// amber, faded over black, is too dark for its near-black name.
struct StationArtworkPlaceholder: View {
    let channel: DRChannel?
    var showsName = true

    var body: some View {
        Group {
            if showsName, let channel {
                StationNameTile(name: channel.name, stationKey: channel.stationKey)
            } else {
                channel?.stationColor ?? .purple
            }
        }
        .accessibilityHidden(true)
    }
}
