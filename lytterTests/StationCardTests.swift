//
//  StationCardTests.swift
//  lytterTests
//

import Testing
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
@testable import lytter

/// A station's name is set at one size on every card and never shrinks to fit, so that "P1"
/// and "P4 - Nordjylland" in the same row are the same size. That only works if every name
/// DR broadcasts fits across every card at that size. These measure it.
///
/// UIKit where there is one, AppKit on the Mac. It imported UIKit unconditionally, so the
/// test target did not build for macOS at all (S17) — and the Mac card, which also puts the
/// playing marker beside the name, was never measured.
///
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct StationCardTests {

    /// Every channel title DR served on 2026-09-26, from /schedules/all/now.
    private static let live = [
        "P1", "P2", "P3",
        "P4 Bornholm", "P4 Esbjerg", "P4 Fyn", "P4 København", "P4 Midt & Vest",
        "P4 Nordjylland", "P4 Sjælland", "P4 Syd", "P4 Trekanten", "P4 Østjylland",
        "P5 Bornholm", "P5 Esbjerg", "P5 Fyn", "P5 København", "P5 Midt & Vest",
        "P5 Nordjylland", "P5 Sjælland", "P5 Syd", "P5 Trekanten", "P5 Østjylland",
        "P6", "P8"
    ]

    /// The spacing `StationCard.Caption` puts between the name and its accessory.
    private static let accessorySpacing: CGFloat = 6

    private func name(_ title: String) -> String {
        DRChannel(id: title.lowercased(), title: title, slug: title.lowercased(),
                  type: "Channel", presentationUrl: nil).qualifiedName
    }

    private func width(of text: String, on metrics: StationCardMetrics) -> CGFloat {
        #if canImport(UIKit)
        let font = UIFont.systemFont(ofSize: metrics.nameFontSize, weight: .bold)
        #else
        let font = NSFont.systemFont(ofSize: metrics.nameFontSize, weight: .bold)
        #endif
        return (text as NSString).size(withAttributes: [.font: font]).width
    }

    /// The width of the playing marker drawn at the card's accessory size.
    private func markerWidth(on metrics: StationCardMetrics) throws -> CGFloat {
        #if canImport(UIKit)
        let marker = try #require(UIImage(
            systemName: "speaker.wave.2.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: metrics.accessoryFontSize)))
        #else
        let marker = try #require(NSImage(systemSymbolName: "speaker.wave.2.fill",
                                          accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: metrics.accessoryFontSize, weight: .regular)))
        #endif
        return marker.size.width
    }

    /// Every name fits `metrics` with the playing marker beside it.
    private func expectEveryNameFitsBesideTheMarker(on metrics: StationCardMetrics) throws {
        let available = room(on: metrics) - Self.accessorySpacing - (try markerWidth(on: metrics))
        for title in Self.live {
            let name = name(title)
            #expect(width(of: name, on: metrics) <= available,
                    "\(name) and the playing marker do not fit a \(metrics.width)-point card")
        }
    }

    private func room(on metrics: StationCardMetrics) -> CGFloat {
        metrics.width - 2 * metrics.horizontalPadding
    }

    @Test(arguments: [StationCardStyle.featured, .standard])
    func everyNameFitsAPhoneCard(style: StationCardStyle) {
        let metrics = StationCardMetrics.iOS(style)
        for title in Self.live {
            let name = name(title)
            #expect(width(of: name, on: metrics) <= room(on: metrics),
                    "\(name) does not fit a \(metrics.width)-point card")
        }
    }

    /// The television marks the playing station beside its name, so any name there has to
    /// fit with the marker next to it.
    @Test(arguments: [StationCardStyle.featured, .standard])
    func everyNameFitsATelevisionCardBesideThePlayingMarker(style: StationCardStyle) throws {
        try expectEveryNameFitsBesideTheMarker(on: .tvOS(style))
    }

    /// So does the Mac's card — and on the standard one the longest district names do not
    /// fit: "P4 - Nordjylland" measures 125 points against 121 available, so a playing
    /// district in Recently Played is truncated. Widening the card cannot fix it (the marker
    /// grows with the card); the design has to change. Recorded as a known issue until it
    /// does — F44 — and this fails the day it is fixed, as a reminder to remove the wrapper.
    @Test(arguments: [StationCardStyle.featured, .standard])
    func everyNameFitsAMacCardBesideThePlayingMarker(style: StationCardStyle) throws {
        try withKnownIssue("F44: long district names overflow the Mac's standard card",
                           isIntermittent: false) {
            try expectEveryNameFitsBesideTheMarker(on: .macOS(style))
        } when: {
            style == .standard
        }
    }
}
