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
    /// A colour for the station, which stands in for its artwork when there is none.
    ///
    /// Fixed per station rather than per channel, so P4 København and P4 Fyn agree. DR's
    /// national stations have one each; anything else gets a colour derived from its name —
    /// stably, which `hashValue` is not: it is seeded per launch, so a colour taken from it
    /// changed every time the app started.
    var stationColor: Color {
        switch name.lowercased() {
        case "p1": .blue
        case "p2": .green
        case "p3": .orange
        case "p4": .purple
        case "p5": .red
        case "p6": .pink
        case "p7": .yellow
        case "p8": .indigo
        default:
            Color(hue: Double(Self.stableSeed(stationKey) % 360) / 360,
                  saturation: 0.6, brightness: 0.75)
        }
    }

    private static func stableSeed(_ text: String) -> Int {
        text.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
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
