//
//  CarPlayCatalogueTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// What the car's screen lists (F21). The templates themselves can only be seen in a car or
/// the simulator's CarPlay window; everything they show is decided here.
@MainActor
struct CarPlayCatalogueTests {

    /// Titled the way DR titles them, so "P4 København" reads as P4's København district.
    private func channel(_ title: String) -> DRChannel {
        DRChannel(id: "urn:" + title.lowercased().replacingOccurrences(of: " ", with: "-"),
                  title: title, slug: title.lowercased(), type: "Channel", presentationUrl: nil)
    }

    private var p1: DRChannel { channel("P1") }
    private var p3: DRChannel { channel("P3") }
    private var p4kbh: DRChannel { channel("P4 København") }
    private var p4fyn: DRChannel { channel("P4 Fyn") }
    private var p4bornholm: DRChannel { channel("P4 Bornholm") }
    private var catalogue: [DRChannel] { [p3, p4fyn, p1, p4kbh, p4bornholm] }

    private func build(favourites: [DRChannel] = [], recent: [DRChannel] = [],
                       context: CarPlayCatalogue.Context = .init()) -> CarPlayCatalogue {
        CarPlayCatalogue(channels: catalogue,
                         favourites: Favourites(channelIDs: favourites.map(\.id)),
                         recentlyPlayed: RecentlyPlayed(channelIDs: recent.map(\.id)),
                         context: context, titles: ("Favourites", "Recent"))
    }

    // MARK: - Home

    @Test func homeListsFavouritesThenRecentlyPlayed() {
        let home = build(favourites: [p4kbh, p1], recent: [p3]).home

        #expect(home.map(\.title) == ["Favourites", "Recent"])
        #expect(home[0].rows.map(\.id) == [p4kbh.id, p1.id])
        #expect(home[1].rows.map(\.id) == [p3.id])
    }

    /// The car's lists are short; a favourite is already one tap away above.
    @Test func recentlyPlayedLeavesOutFavourites() {
        let home = build(favourites: [p1], recent: [p3, p1, p4fyn]).home

        #expect(home[1].rows.map(\.id) == [p3.id, p4fyn.id])
    }

    /// A first drive has neither; the template's empty view says so rather than headings.
    @Test func emptySectionsAreLeftOut() {
        #expect(build().home.isEmpty)
        #expect(build(recent: [p3]).home.map(\.title) == ["Recent"])
        #expect(build(favourites: [p1], recent: [p1]).home.map(\.title) == ["Favourites"])
    }

    /// A pinned district is that district: "P4" alone would not say which of the ten.
    @Test func homeRowsPlayTheChannelNamedInFull() {
        let row = build(favourites: [p4kbh]).home[0].rows[0]

        #expect(row.title == "P4 - København")
        #expect(row.action == .play(p4kbh))
    }

    // MARK: - Stations

    @Test func stationsAreOneRowAStationInNameOrder() {
        let stations = build().stations

        #expect(stations.map(\.title) == ["P1", "P3", "P4"])
    }

    @Test func aStationWithoutDistrictsPlays() {
        let row = build().stations.first { $0.title == "P1" }

        #expect(row?.action == .play(p1))
    }

    /// Driving is when a listener leaves their region, so P4 always asks.
    @Test func aStationWithDistrictsOpensThemEvenWithARegion() {
        let context = CarPlayCatalogue.Context(region: District(name: "Fyn"))
        let row = build(context: context).stations.first { $0.title == "P4" }

        guard case .chooseDistrict(let stationID)? = row?.action else {
            Issue.record("P4 should open its districts, not \(String(describing: row?.action))")
            return
        }
        #expect(stationID == GroupedChannel.grouped(from: catalogue).first { $0.name == "P4" }?.id)
    }

    @Test func districtsListTheRegionFirst() throws {
        let context = CarPlayCatalogue.Context(region: District(name: "Fyn"))
        let p4 = try #require(GroupedChannel.grouped(from: catalogue).first { $0.name == "P4" })

        let rows = try #require(CarPlayCatalogue.districts(of: p4.id, in: catalogue, context: context))

        #expect(rows.map(\.title) == ["Fyn", "Bornholm", "København"])
        #expect(rows.first?.action == .play(p4fyn))
    }

    @Test func districtsOfAStationThatHasNoneOrIsGoneAreNil() {
        #expect(CarPlayCatalogue.districts(of: p1.id, in: catalogue, context: .init()) == nil)
        #expect(CarPlayCatalogue.districts(of: "urn:gone", in: catalogue, context: .init()) == nil)
    }

    // MARK: - What a row shows

    @Test func rowsShowWhatIsOnAndItsArtwork() {
        let context = CarPlayCatalogue.Context(programme: { "On \($0.slug)" },
                                               artwork: { "https://img/\($0.slug)" })
        let row = build(favourites: [p3], context: context).home[0].rows[0]

        #expect(row.detail == "On p3")
        #expect(row.imageURL == "https://img/p3")
    }

    /// Another district's programme would be a guess at what the listener will hear.
    @Test func aStationOfDistrictsShowsItsProgrammeOnlyForTheRegion() {
        let programme: (DRChannel) -> String? = { "On \($0.slug)" }
        let withRegion = CarPlayCatalogue.Context(region: District(name: "Fyn"), programme: programme)
        let without = CarPlayCatalogue.Context(programme: programme)

        #expect(build(context: withRegion).stations.first { $0.title == "P4" }?.detail == "On p4 fyn")
        #expect(build(context: without).stations.first { $0.title == "P4" }?.detail == nil)
    }

    @Test func theAudibleChannelIsMarkedPlayingAndItsStationToo() {
        let context = CarPlayCatalogue.Context(audibleChannelID: p4fyn.id)
        let built = build(favourites: [p4fyn, p1], context: context)

        #expect(built.home[0].rows.map(\.isPlaying) == [true, false])
        #expect(built.stations.filter(\.isPlaying).map(\.title) == ["P4"])
    }

    // MARK: - The car's limits

    @Test func cappingKeepsTheFirstRowsAndDropsEmptiedSections() {
        let sections = build(favourites: [p1, p3], recent: [p4kbh, p4fyn]).home

        let capped = CarPlayCatalogue.capped(sections, items: 3, sections: 5)
        #expect(capped.map { $0.rows.map(\.id) } == [[p1.id, p3.id], [p4kbh.id]])

        let favouritesOnly = CarPlayCatalogue.capped(sections, items: 2, sections: 5)
        #expect(favouritesOnly.map(\.title) == ["Favourites"])

        let oneSection = CarPlayCatalogue.capped(sections, items: 10, sections: 1)
        #expect(oneSection.map(\.title) == ["Favourites"])
    }

    /// The scene redraws only when this changes; equal inputs must build equal catalogues.
    @Test func sameInputsBuildAnEqualCatalogue() {
        #expect(build(favourites: [p1], recent: [p3]) == build(favourites: [p1], recent: [p3]))
        #expect(build(favourites: [p1]) != build(favourites: [p3]))
    }
}
