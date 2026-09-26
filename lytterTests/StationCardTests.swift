//
//  StationCardTests.swift
//  lytterTests
//

import Testing
import UIKit
@testable import lytter

/// A station's name is set at one size on every card and never shrinks to fit, so that "P1"
/// and "P4 - Nordjylland" in the same row are the same size. That only works if every name
/// DR broadcasts fits across every card at that size. These measure it.
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
        let font = UIFont.systemFont(ofSize: metrics.nameFontSize, weight: .bold)
        return (text as NSString).size(withAttributes: [.font: font]).width
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
        let metrics = StationCardMetrics.tvOS(style)
        let marker = try #require(UIImage(
            systemName: "speaker.wave.2.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: metrics.accessoryFontSize)))
        let available = room(on: metrics) - Self.accessorySpacing - marker.size.width

        for title in Self.live {
            let name = name(title)
            #expect(width(of: name, on: metrics) <= available,
                    "\(name) and the playing marker do not fit a \(metrics.width)-point card")
        }
    }
}
