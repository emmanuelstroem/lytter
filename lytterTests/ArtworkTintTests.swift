//
//  ArtworkTintTests.swift
//  lytterTests
//

// The platforms ArtworkTint is built for that the unit tests run on; the Mac has no UIKit.
#if os(iOS) || os(visionOS)
import Testing
import SwiftUI
import UIKit
@testable import lytter

/// White reads on `ArtworkTint.fill`, the schedule's row on air, whatever the artwork's
/// colour: 4.5:1 at the least, the WCAG minimum for text the size of the row's title.
@MainActor
struct ArtworkTintTests {

    private static let leastContrast = 4.5

    /// WCAG relative luminance.
    private func luminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func linear(_ c: CGFloat) -> Double {
            let c = Double(c)
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    private func whiteContrast(on tint: ArtworkTint) -> Double {
        1.05 / (luminance(tint.broughtColor(brightness: ArtworkTint.fillBrightness)) + 0.05)
    }

    /// Every hue, from grey to fully saturated: an artwork can average to any of them.
    @Test func whiteReadsOnTheFillOfAnyArtwork() {
        for hue in stride(from: 0.0, through: 1.0, by: 0.02) {
            for saturation in stride(from: 0.0, through: 1.0, by: 0.1) {
                let tint = ArtworkTint(hue: hue, saturation: saturation, brightness: 0.8)
                let contrast = whiteContrast(on: tint)
                #expect(contrast >= Self.leastContrast,
                        "hue \(hue), saturation \(saturation): \(contrast):1")
            }
        }
    }

    /// With no artwork the fill is the station's colour brought the same way, and P3's
    /// light green is the station that needed it: white on its own colour does not read.
    @Test func whiteReadsOnTheFillOfEveryStation() {
        for station in StationPalette.national.keys.sorted() {
            let tint = ArtworkTint(StationPalette.color(stationName: station, stationKey: station))
            let contrast = whiteContrast(on: tint)
            #expect(contrast >= Self.leastContrast, "\(station): \(contrast):1")
        }
    }
}
#endif
