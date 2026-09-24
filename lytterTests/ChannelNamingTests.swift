//
//  ChannelNamingTests.swift
//  lytterTests
//

import Testing
@testable import lytter

/// A channel's station and district are parsed out of one string — DR sends "P4 København"
/// and nothing else. That parsing decides how channels group into stations, so a change to
/// it silently rearranges the whole home screen. These pin it.
///
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct ChannelNamingTests {

    private func channel(_ title: String) -> DRChannel {
        DRChannel(id: title.lowercased(), title: title, slug: title.lowercased(),
                  type: "Channel", presentationUrl: nil)
    }

    /// Every channel title DR served on 2026-09-24, from /schedules/all/now.
    private static let live = [
        "P1", "P2", "P3",
        "P4 Bornholm", "P4 Esbjerg", "P4 Fyn", "P4 København", "P4 Midt & Vest",
        "P4 Nordjylland", "P4 Sjælland", "P4 Syd", "P4 Trekanten", "P4 Østjylland",
        "P5 Bornholm", "P5 Esbjerg", "P5 Fyn", "P5 København", "P5 Midt & Vest",
        "P5 Nordjylland", "P5 Sjælland", "P5 Syd", "P5 Trekanten", "P5 Østjylland",
        "P6", "P8"
    ]

    @Test func aNationalChannelHasNoDistrict() {
        let p1 = channel("P1")

        #expect(p1.name == "P1")
        #expect(p1.district == nil)
        #expect(p1.qualifiedName == "P1", "with no district there is nothing to append")
    }

    @Test func aRegionalChannelNamesItsDistrict() {
        let kbh = channel("P4 København")

        #expect(kbh.name == "P4")
        #expect(kbh.district == "København")
        #expect(kbh.qualifiedName == "P4 - København")
    }

    /// The title splits once, not on every space — otherwise the district of
    /// "P4 Midt & Vest" would be "Midt" and three real channels would lose their names.
    @Test func aDistrictMayContainSpaces() {
        #expect(channel("P4 Midt & Vest").district == "Midt & Vest")
        #expect(channel("P4 Midt & Vest").qualifiedName == "P4 - Midt & Vest")
    }

    /// What the parsing actually keys on is the first space, not a list of stations that
    /// have districts. DR ships nothing that breaks this today — every title with a space
    /// is a genuine P4 or P5 district. Recorded so that the day a "P6 Beat" or a second
    /// broadcaster's "Radio 4 Nyheder" appears, the failure is a known one rather than a
    /// mystery about why it joined a station it has nothing to do with.
    @Test func aTwoWordStationNameWouldBeReadAsADistrict() {
        let beat = channel("P6 Beat")

        #expect(beat.name == "P6")
        #expect(beat.district == "Beat", "not a district — this is the heuristic's limit")
    }

    @Test func liveTitlesGroupIntoSevenStations() {
        let groups = GroupedChannel.grouped(from: Self.live.map(channel))

        #expect(groups.map(\.name) == ["P1", "P2", "P3", "P4", "P5", "P6", "P8"])
    }

    @Test func onlyP4AndP5HaveDistricts() {
        let groups = GroupedChannel.grouped(from: Self.live.map(channel))
        let districted = groups.filter(\.hasMultipleDistricts)

        #expect(districted.map(\.name) == ["P4", "P5"])
        #expect(districted.allSatisfy { $0.channels.count == 10 })
    }

    /// A card standing for one channel says which district it is; a card standing for the
    /// station does not. Favourites holds specific channels, so without this a shelf shows
    /// several cards all captioned "P4".
    @Test func aSingleChannelCardNamesItsDistrict() {
        let group = GroupedChannel(channels: [channel("P4 København")])

        #expect(group.displayTitle == "P4 - København")
    }

    @Test func aStationCardIsNamedForTheStation() {
        let group = GroupedChannel(channels: [channel("P4 København"), channel("P4 Fyn")])

        #expect(group.displayTitle == "P4", "the card stands for both, so it names neither")
        #expect(group.hasMultipleDistricts)
    }

    @Test func aSingleChannelWithNoDistrictIsUnchanged() {
        #expect(GroupedChannel(channels: [channel("P3")]).displayTitle == "P3")
    }

    /// Districts are listed in a stable order regardless of how the API returned them —
    /// the picker would otherwise reshuffle between launches.
    @Test func districtsAreOrdered() {
        let shuffled = ["P4 Syd", "P4 Bornholm", "P4 Fyn"].map(channel)

        let group = GroupedChannel(channels: shuffled)

        #expect(group.districts == ["Bornholm", "Fyn", "Syd"])
    }
}
