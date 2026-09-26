//
//  ChannelDirectoryTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// Station and district used to be read from a channel's title by splitting it on the
/// first space. DR's `/channels` states both outright, and these pin that the app takes
/// DR's word — in particular for the case the title split gets wrong, a national channel
/// with a two-word name. DR's directory already has one, "P7 MIX".
///
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct ChannelDirectoryTests {

    /// Cut down from `/channels` on 2026-09-27: the fields the directory reads, for a
    /// station with no districts, one with districts, and two whose slug or title does
    /// not match the title-split rule.
    private static let fixture = #"""
    [
      { "slug": "p1", "title": "P1", "isDistrict": false },
      { "slug": "p4", "title": "P4", "isDistrict": false, "districts": [
          { "slug": "p4bornholm", "title": "P4 Bornholm", "districtName": "Bornholm",
            "isDistrict": true, "parentChannelSlug": "p4" },
          { "slug": "p4vest", "title": "P4 Midt & Vest", "districtName": "Midt & Vest",
            "isDistrict": true, "parentChannelSlug": "p4" }
      ] },
      { "slug": "p6beat", "title": "P6", "isDistrict": false },
      { "slug": "p7mix", "title": "P7 MIX", "isDistrict": false }
    ]
    """#

    private func directory() throws -> ChannelDirectory {
        let stations = try JSONDecoder().decode([ChannelDirectory.Station].self,
                                                from: Data(Self.fixture.utf8))
        return ChannelDirectory(stations: stations)
    }

    private func channel(_ title: String, slug: String) -> DRChannel {
        DRChannel(id: "urn:\(slug)", title: title, slug: slug,
                  type: "Channel", presentationUrl: nil)
    }

    // MARK: - What DR says

    @Test func aDistrictBelongsToTheStationDRNames() throws {
        let bornholm = try directory().apply(to: channel("P4 Bornholm", slug: "p4bornholm"))

        #expect(bornholm.name == "P4")
        #expect(bornholm.district == "Bornholm")
        #expect(bornholm.stationKey == "p4")
    }

    @Test func aDistrictWithSpacesKeepsItsWholeName() throws {
        let vest = try directory().apply(to: channel("P4 Midt & Vest", slug: "p4vest"))

        #expect(vest.district == "Midt & Vest")
        #expect(vest.qualifiedName == "P4 - Midt & Vest")
    }

    /// The case F6b exists for. Split on its first space, "P7 MIX" is station P7 with a
    /// district called MIX.
    @Test func aTwoWordNationalChannelIsNotADistrict() throws {
        let mix = try directory().apply(to: channel("P7 MIX", slug: "p7mix"))

        #expect(mix.name == "P7 MIX")
        #expect(mix.district == nil)
        #expect(mix.qualifiedName == "P7 MIX")
    }

    /// And it stays a station of its own when grouped, rather than joining another
    /// channel whose title begins with "P7".
    @Test func aTwoWordNationalChannelIsAStationOfItsOwn() throws {
        let dir = try directory()
        let channels = [channel("P7 MIX", slug: "p7mix"), channel("P7", slug: "p7")]
            .map(dir.apply)

        let groups = GroupedChannel.grouped(from: channels)

        #expect(groups.count == 2)
        #expect(groups.allSatisfy { !$0.hasMultipleDistricts })
    }

    /// A title is display text; the slug is the identity. Two stations that happen to share
    /// a title — a second broadcaster's "P4", or DR reusing a name — stay two stations.
    @Test func stationsAreToldApartBySlugNotTitle() {
        let directory = ChannelDirectory(entries: [
            "p4": .init(stationSlug: "p4", stationTitle: "P4", districtName: nil),
            "other-p4": .init(stationSlug: "other-p4", stationTitle: "P4", districtName: nil)
        ])
        let channels = [channel("P4", slug: "p4"), channel("P4", slug: "other-p4")]
            .map(directory.apply)

        #expect(GroupedChannel.grouped(from: channels).count == 2)
    }

    @Test func districtsStillGroupUnderTheirStation() throws {
        let dir = try directory()
        let channels = [channel("P4 Bornholm", slug: "p4bornholm"),
                        channel("P4 Midt & Vest", slug: "p4vest"),
                        channel("P1", slug: "p1")].map(dir.apply)

        let groups = GroupedChannel.grouped(from: channels)

        #expect(groups.map(\.name) == ["P1", "P4"])
        #expect(groups.first { $0.name == "P4" }?.channels.count == 2)
    }

    // MARK: - When DR says nothing

    /// A channel the directory does not list reads its title, as before, rather than
    /// losing its name.
    @Test func anUnlistedChannelFallsBackToItsTitle() throws {
        let unlisted = try directory().apply(to: channel("P4 Fyn", slug: "p4fyn"))

        #expect(unlisted.name == "P4")
        #expect(unlisted.district == "Fyn")
        #expect(unlisted.stationSlug == nil)
    }

    /// The directory is not stored on its own. What was applied to the cached channels is
    /// all there is to fall back on when `/channels` cannot be reached.
    @Test func aDirectoryCanBeRecoveredFromChannelsItWasAppliedTo() throws {
        let dir = try directory()
        let applied = [channel("P4 Bornholm", slug: "p4bornholm"),
                       channel("P7 MIX", slug: "p7mix")].map(dir.apply)

        let recovered = ChannelDirectory(learningFrom: applied)

        #expect(recovered.apply(to: channel("P7 MIX", slug: "p7mix")).district == nil)
        #expect(recovered.apply(to: channel("P4 Bornholm", slug: "p4bornholm")).stationKey == "p4")
    }

    /// Survives the disk cache: the directory's fields are encoded with the channel.
    @Test func whatTheDirectorySaidSurvivesEncoding() throws {
        let applied = try directory().apply(to: channel("P7 MIX", slug: "p7mix"))

        let decoded = try JSONDecoder().decode(DRChannel.self,
                                               from: JSONEncoder().encode(applied))

        #expect(decoded.stationSlug == "p7mix")
        #expect(decoded.district == nil)
    }
}
