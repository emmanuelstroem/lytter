//
//  StationPaletteTests.swift
//  lytterTests
//

import SwiftUI
import Testing
@testable import lytter
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// DR's stations are drawn as their name on DR's colour (S11): the app carries DR's
/// colours, and no DR artwork.
struct StationPaletteTests {

    /// WCAG relative luminance of an sRGB colour.
    private static func luminance(_ rgb: UInt32) -> Double {
        func channel(_ value: UInt32) -> Double {
            let c = Double(value & 0xFF) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(rgb >> 16) + 0.7152 * channel(rgb >> 8) + 0.0722 * channel(rgb)
    }

    private static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    @Test func everyNationalStationHasAColour() {
        #expect(Set(StationPalette.national.keys) == ["p1", "p2", "p3", "p4", "p5", "p6", "p8"])
    }

    /// The name is set large and heavy, so 3:1 is the floor (WCAG 1.4.3, large text) — and
    /// of white and near-black, the palette must pick the one that reads better.
    @Test(arguments: StationPalette.national.keys.sorted())
    func nameReadsOnItsColour(station: String) throws {
        let entry = try #require(StationPalette.national[station])
        let chosen = entry.darkText ? StationPalette.darkText : 0xFFFFFF
        let other = entry.darkText ? 0xFFFFFF : StationPalette.darkText
        let chosenContrast = Self.contrast(entry.rgb, chosen)
        #expect(chosenContrast >= 3, "\(station): \(chosenContrast) against its text")
        #expect(chosenContrast >= Self.contrast(entry.rgb, other), "\(station): the other text colour reads better")
    }

    /// `textColor` follows the table, whatever the case of the name the directory gives.
    @Test func textColourFollowsTheTable() {
        let environment = EnvironmentValues()
        let p3 = StationPalette.textColor(stationName: "P3").resolve(in: environment)
        let p2 = StationPalette.textColor(stationName: "p2").resolve(in: environment)
        #expect(abs(Double(p3.red) - Double(0x23) / 255) < 0.01)
        #expect(p2.red == 1 && p2.green == 1 && p2.blue == 1)
    }

    /// Every DR name fits across its tile at full size, inside the padding, so none is
    /// shrunk to fit and every tile's name is the same size as its neighbours'. Measured
    /// on a 100-point tile; the type scales with the tile, so the share holds at any size.
    @Test(arguments: StationPalette.national.keys.sorted())
    func nameFitsItsTileAtFullSize(station: String) {
        let width: CGFloat = 100
        let size = StationTileType.size(forWidth: width)
        #if canImport(UIKit)
        let font = UIFont.systemFont(ofSize: size, weight: .heavy)
        #else
        let font = NSFont.systemFont(ofSize: size, weight: .heavy)
        #endif
        let measured = (station.uppercased() as NSString).size(withAttributes: [
            .font: font, .kern: size * StationTileType.trackingShare,
        ]).width
        let room = width * (1 - 2 * StationTileType.paddingShare)
        #expect(measured <= room, "\(station) is \(measured) wide on a tile with \(room) of room")
    }

    /// The programme's picture shows through a tile only away from the name's colour: it
    /// darkens under a white name and lightens under a near-black one, so wherever the
    /// picture is darkest or lightest the name reads at least as well as on the plain colour.
    /// Checked at full strength against black and white, the picture's extremes.
    @Test(arguments: StationPalette.national.keys.sorted())
    func artworkOnlyMovesTheColourAwayFromTheName(station: String) throws {
        let entry = try #require(StationPalette.national[station])
        let text = entry.darkText ? StationPalette.darkText : 0xFFFFFF
        let blend = StationTileArtwork.blendMode(stationName: station)
        func blended(_ backdrop: UInt32, _ picture: UInt32) -> UInt32 {
            func channel(_ shift: UInt32) -> UInt32 {
                let (b, p) = (Double((backdrop >> shift) & 0xFF) / 255, Double((picture >> shift) & 0xFF) / 255)
                let value = blend == .multiply ? b * p : blend == .screen ? 1 - (1 - b) * (1 - p) : p
                return UInt32((value * 255).rounded()) << shift
            }
            return channel(16) | channel(8) | channel(0)
        }
        let flat = Self.contrast(entry.rgb, text)
        for picture: UInt32 in [0x000000, 0x808080, 0xFFFFFF] {
            let tile = blended(entry.rgb, picture)
            #expect(Self.contrast(tile, text) >= flat - 0.01,
                    "\(station): a \(String(picture, radix: 16)) picture brings the name to \(Self.contrast(tile, text))")
        }
    }

    /// The logos went with the assets that held them; nothing in the app draws DR's.
    @Test(arguments: ["DRLydLogo", "DRP1Logo", "DRP3Logo", "DRP8Logo"])
    func noDRLogoShips(name: String) {
        #if canImport(UIKit)
        #expect(UIImage(named: name) == nil)
        #else
        #expect(NSImage(named: name) == nil)
        #endif
    }
}
