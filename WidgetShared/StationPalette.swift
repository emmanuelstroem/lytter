//
//  StationPalette.swift
//  WidgetShared
//

import SwiftUI

/// A colour for each station, standing in for artwork where there is none, and the colour
/// its name is written in on top.
///
/// Here rather than on `DRChannel` so the widget extension, which has no `DRChannel`, draws
/// the same colours as the app (F18). `DRChannel.stationColor` asks this.
///
/// Fixed per station rather than per channel, so P4 København and P4 Fyn agree. DR's
/// national stations have DR's own colours; anything else gets a colour derived from its
/// key — stably, which `hashValue` is not: it is seeded per launch, so a colour taken from
/// it changed every time the app started.
nonisolated enum StationPalette {
    /// DR's colour for each national station, in sRGB, as ColorSync converts the CMYK of
    /// DR's logos; and whether the name goes on it in near-black rather than white. Only
    /// the colours are DR's — the app draws no DR artwork (no logo, no lettering): a
    /// station's tile is its name in the system font on this colour.
    ///
    /// The text colour is whichever of white and near-black reads better, which is not
    /// always what DR's logos use: white on P1's orange and P4's amber is under 3:1, the
    /// least for large text. `StationPaletteTests` holds each choice to that.
    static let national: [String: (rgb: UInt32, darkText: Bool)] = [
        "p1": (0xEA7C36, true),
        "p2": (0x2E4C94, false),
        "p3": (0x76C177, true),
        "p4": (0xF1A53A, true),
        "p5": (0xC1276C, false),
        "p6": (0x4E5357, false),
        "p8": (0x685F9D, false),
    ]

    /// The near-black of DR's logos (100% K through ColorSync), for a name on a light colour.
    static let darkText: UInt32 = 0x232121

    static func color(stationName: String, stationKey: String) -> Color {
        if let station = national[stationName.lowercased()] {
            return Color(rgb: station.rgb)
        }
        return Color(hue: Double(stableSeed(stationKey) % 360) / 360,
                     saturation: 0.6, brightness: 0.75)
    }

    /// What the station's name is written in, on `color(stationName:stationKey:)`.
    static func textColor(stationName: String) -> Color {
        national[stationName.lowercased()]?.darkText == true ? Color(rgb: darkText) : .white
    }

    private static func stableSeed(_ text: String) -> Int {
        text.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
    }
}

private extension Color {
    nonisolated init(rgb: UInt32) {
        self.init(.sRGB,
                  red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255)
    }
}
