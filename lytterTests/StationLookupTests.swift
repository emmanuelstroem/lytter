//
//  StationLookupTests.swift
//  lytterTests
//

import Testing
@testable import lytter

/// What a station named to Siri or Shortcuts resolves to (F15). Search lists choices; Siri
/// has to act, so "P4" means the listener's own district when they have one.
@MainActor
struct StationLookupTests {

    private static let titles = [
        "P1", "P2", "P3",
        "P4 Bornholm", "P4 Fyn", "P4 København", "P4 Østjylland",
        "P5 Bornholm", "P5 Fyn", "P5 København",
        "P6", "P8"
    ]

    private var channels: [DRChannel] {
        Self.titles.map {
            DRChannel(id: $0.lowercased(), title: $0, slug: $0.lowercased(),
                      type: "Channel", presentationUrl: nil)
        }
    }

    private func names(for query: String, region: String? = nil) -> [String] {
        StationLookup.channels(answering: query, in: channels,
                               region: region.map(District.init(name:)))
            .map(\.qualifiedName)
    }

    @Test func aNationalStationIsItself() {
        #expect(names(for: "P3") == ["P3"])
    }

    /// The point of the region: "Play P4" plays the listener's P4 without asking.
    @Test func aRegionalStationIsTheListenersDistrict() {
        #expect(names(for: "P4", region: "Fyn") == ["P4 - Fyn"])
    }

    /// With no region Siri has to ask, so every district is offered.
    @Test func withoutARegionEveryDistrictIsOffered() {
        #expect(names(for: "P4") == ["P4 - Bornholm", "P4 - Fyn", "P4 - København",
                                     "P4 - Østjylland"])
    }

    /// A region the station does not broadcast is no help; offer them all.
    @Test func aRegionTheStationLacksOffersEveryDistrict() {
        #expect(names(for: "P5", region: "Østjylland").count == 3)
    }

    @Test func aNamedDistrictIsThatDistrict() {
        #expect(names(for: "P5 København", region: "Fyn") == ["P5 - København"])
    }

    @Test func aDistrictNameAloneFindsItOnEveryStation() {
        #expect(names(for: "Bornholm") == ["P4 - Bornholm", "P5 - Bornholm"])
    }

    @Test func somethingNobodyBroadcastsIsNothing() {
        #expect(names(for: "zzzz").isEmpty)
    }
}
