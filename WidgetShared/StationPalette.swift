//
//  StationPalette.swift
//  WidgetShared
//

import SwiftUI

/// A colour for each station, standing in for artwork where there is none.
///
/// Here rather than on `DRChannel` so the widget extension, which has no `DRChannel`, draws
/// the same colours as the app (F18). `DRChannel.stationColor` asks this.
///
/// Fixed per station rather than per channel, so P4 København and P4 Fyn agree. DR's
/// national stations have one each; anything else gets a colour derived from its key —
/// stably, which `hashValue` is not: it is seeded per launch, so a colour taken from it
/// changed every time the app started.
nonisolated enum StationPalette {
    static func color(stationName: String, stationKey: String) -> Color {
        switch stationName.lowercased() {
        case "p1": .blue
        case "p2": .green
        case "p3": .orange
        case "p4": .purple
        case "p5": .red
        case "p6": .pink
        case "p7": .yellow
        case "p8": .indigo
        default:
            Color(hue: Double(stableSeed(stationKey) % 360) / 360,
                  saturation: 0.6, brightness: 0.75)
        }
    }

    private static func stableSeed(_ text: String) -> Int {
        text.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
    }
}
