//
//  StationCardTests.swift
//  lytterTests
//

import Testing
@testable import lytter

// The phone's and the headset's shelf card, which these are about.
#if os(iOS) || os(visionOS)
/// Which card the playing mark goes on.
///
/// These measured, too, that every name DR broadcasts fits across a card, beside the playing
/// marker, at the caption's one size. The caption has gone: a card is the station's tile, and
/// the tile sets the name to its own width (`StationNameTile`), with the marker in the corner.
///
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct StationCardTests {

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
}
#endif
