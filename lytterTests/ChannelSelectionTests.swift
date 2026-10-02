//
//  ChannelSelectionTests.swift
//  lytterTests
//

import Testing
@testable import lytter

/// Selecting a station that is already on must not restart it (F41). It restarts only when
/// the channel or the district differs, or when nothing usable is loaded.
///
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct ChannelSelectionTests {

    private let p1 = DRChannel(id: "urn:p1", title: "P1", slug: "p1", type: "Channel",
                               presentationUrl: nil)
    private let p4kbh = DRChannel(id: "urn:p4kbh", title: "P4 København", slug: "p4kbh",
                                  type: "Channel", presentationUrl: nil,
                                  stationSlug: "p4", stationTitle: "P4", districtName: "København")
    private let p4aarhus = DRChannel(id: "urn:p4aarhus", title: "P4 Aarhus", slug: "p4aarhus",
                                     type: "Channel", presentationUrl: nil,
                                     stationSlug: "p4", stationTitle: "P4", districtName: "Aarhus")

    private func action(_ channel: DRChannel, loaded: DRChannel?,
                        hasLoadedItem: Bool = true, isPlaying: Bool = true) -> DRServiceManager.SelectionAction {
        DRServiceManager.selectionAction(for: channel, loaded: loaded,
                                         hasLoadedItem: hasLoadedItem, isPlaying: isPlaying)
    }

    @Test func theStationAlreadyPlayingIsLeftAlone() {
        #expect(action(p1, loaded: p1) == .nothing)
    }

    @Test func theSameDistrictAlreadyPlayingIsLeftAlone() {
        #expect(action(p4kbh, loaded: p4kbh) == .nothing)
    }

    @Test func anotherChannelRestarts() {
        #expect(action(p1, loaded: p4kbh) == .restart)
    }

    /// Same station, different district: a different stream, so it has to restart.
    @Test func anotherDistrictOfTheSameStationRestarts() {
        #expect(action(p4aarhus, loaded: p4kbh) == .restart)
    }

    @Test func thePausedStationResumesRatherThanReloading() {
        #expect(action(p1, loaded: p1, isPlaying: false) == .resume)
    }

    /// Restored at launch but never started, or the item failed: there is nothing to
    /// resume, so selecting it has to start the stream.
    @Test func aLoadedChannelWithNoUsableItemRestarts() {
        #expect(action(p1, loaded: p1, hasLoadedItem: false, isPlaying: false) == .restart)
    }

    @Test func nothingLoadedRestarts() {
        #expect(action(p1, loaded: nil, hasLoadedItem: false, isPlaying: false) == .restart)
    }
}
