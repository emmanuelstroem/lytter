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

// The same platforms as StationCard itself.
#if os(iOS) || os(tvOS) || os(macOS) || os(visionOS)
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
            systemName: PlayingMark.sizingSymbol,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: metrics.accessoryFontSize)))
        #else
        let marker = try #require(NSImage(systemSymbolName: PlayingMark.sizingSymbol,
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

    #if os(iOS) || os(visionOS)
    /// A card is the station: P4's is marked whichever district is playing — each in turn,
    /// whatever order the group keeps them in.
    @Test func aStationsCardIsMarkedWhicheverDistrictPlays() {
        let p4 = GroupedChannel(channels: [channel("p4kbh"), channel("p4fyn"), channel("p4syd")])

        for district in p4.channels {
            #expect(ChannelShelfCard.isPlaying(p4, loaded: district, isPlaying: true),
                    "P4's card is not marked while \(district.id) plays")
        }
    }

    /// Loaded but paused is not playing: the mark says "now".
    @Test func aPausedStationIsNotMarked() {
        let p1 = GroupedChannel(channels: [channel("p1")])

        #expect(!ChannelShelfCard.isPlaying(p1, loaded: channel("p1"), isPlaying: false))
    }

    @Test func anotherStationPlayingDoesNotMarkThisOne() {
        let p1 = GroupedChannel(channels: [channel("p1")])

        #expect(!ChannelShelfCard.isPlaying(p1, loaded: channel("p2"), isPlaying: true))
    }

    private func channel(_ id: String) -> DRChannel {
        DRChannel(id: id, title: id.uppercased(), slug: id, type: "Channel", presentationUrl: nil)
    }
    #endif

    /// The television marks the playing station beside its name, so any name there has to
    /// fit with the marker next to it.
    @Test(arguments: [StationCardStyle.featured, .standard])
    func everyNameFitsATelevisionCardBesideThePlayingMarker(style: StationCardStyle) throws {
        try expectEveryNameFitsBesideTheMarker(on: .tvOS(style))
    }

    #if os(macOS)
    /// The Mac's card marks it beside the name only where every name fits with it; on the
    /// standard card the longest districts do not ("P4 - Nordjylland" measures 125 points
    /// against 121), so there the marker leads the programme beneath the card and the name
    /// has the caption to itself (F44).
    @Test(arguments: [StationCardStyle.featured, .standard])
    func everyNameFitsAMacCard(style: StationCardStyle) throws {
        let metrics = StationCardMetrics.macOS(style)
        if macOSStationCard.marksPlayingBesideName(style) {
            try expectEveryNameFitsBesideTheMarker(on: metrics)
        } else {
            for title in Self.live {
                let name = name(title)
                #expect(width(of: name, on: metrics) <= room(on: metrics),
                        "\(name) does not fit a \(metrics.width)-point card")
            }
        }
    }
    #endif
}
#endif
