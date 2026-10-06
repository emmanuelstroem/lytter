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
/// twice.
struct StationArtworkPlaceholder: View {
    let channel: DRChannel?
    var showsName = true

    var body: some View {
        let colour = channel?.stationColor ?? .purple
        LinearGradient(colors: [colour, colour.opacity(0.6)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                if showsName, let channel {
                    GeometryReader { proxy in
                        let side = min(proxy.size.width, proxy.size.height)
                        // The station's own name: a proper noun, not for the catalogue.
                        Text(verbatim: channel.name)
                            .font(.system(size: side * 0.3, weight: .heavy, design: .rounded))
                            .minimumScaleFactor(0.3)
                            .lineLimit(1)
                            .foregroundStyle(Color.white)
                            .padding(side * 0.08)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .accessibilityHidden(true)
    }
}
