//
//  PlayingMarkerTests.swift
//  lytterTests
//

import Testing
@testable import lytter

/// The speaker mark on a card says the station can be heard now. It used to follow
/// whichever channel was loaded in the player, so it stayed on a paused channel, and on the
/// last-played channel restored at launch without being started.
///
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct PlayingMarkerTests {

    private let p1 = DRChannel(id: "urn:p1", title: "P1", slug: "p1", type: "Channel",
                               presentationUrl: nil)
    private let p2 = DRChannel(id: "urn:p2", title: "P2", slug: "p2", type: "Channel",
                               presentationUrl: nil)

    @Test func theLoadedChannelIsMarkedWhilePlaying() {
        #expect(DRServiceManager.isAudible(p1, loaded: p1, isPlaying: true))
    }

    /// Loaded but silent: paused, or the last-played channel restored at launch and never
    /// started. Both look the same to the player, and neither is playing.
    @Test func aLoadedChannelThatIsNotPlayingIsNotMarked() {
        #expect(!DRServiceManager.isAudible(p1, loaded: p1, isPlaying: false))
    }

    @Test func anotherChannelIsNotMarked() {
        #expect(!DRServiceManager.isAudible(p2, loaded: p1, isPlaying: true))
    }

    @Test func nothingIsMarkedWithNothingLoaded() {
        #expect(!DRServiceManager.isAudible(p1, loaded: nil, isPlaying: true))
    }
}
