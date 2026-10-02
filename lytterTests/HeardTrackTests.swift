//
//  HeardTrackTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// Behind live, the track shown is the one being heard, not the one on air. DR's track
/// list is newest first and runs back about an hour, which covers the DVR window.
///
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct HeardTrackTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func track(_ title: String, startedSecondsAgo: TimeInterval, lasting: TimeInterval) -> DRTrack {
        let start = ISO8601DateFormatter().string(from: now.addingTimeInterval(-startedSecondsAgo))
        return DRTrack(type: "Track", durationMilliseconds: Int(lasting * 1000), playedTime: start,
                       musicUrl: "", trackUrn: "urn:\(title)", classical: false, roles: nil,
                       title: title, description: "")
    }

    /// Newest first, as DR sends it: "Now" started 60 s ago, "Before" ran 260–60 s ago.
    private var tracks: [DRTrack] {
        [track("Now", startedSecondsAgo: 60, lasting: 200),
         track("Before", startedSecondsAgo: 260, lasting: 200)]
    }

    @Test func atLiveTheTrackOnAirIsHeard() {
        #expect(DRServiceManager.heardTrack(in: tracks, at: now)?.title == "Now")
    }

    /// 90 s behind is 30 s before "Now" started: still in "Before".
    @Test func behindLiveTheEarlierTrackIsHeard() {
        let heard = DRServiceManager.heardTrack(in: tracks, at: now.addingTimeInterval(-90))
        #expect(heard?.title == "Before")
    }

    /// Talk between tracks: nothing matches, so no track is shown.
    @Test func aGapBetweenTracksShowsNone() {
        #expect(DRServiceManager.heardTrack(in: tracks, at: now.addingTimeInterval(-400)) == nil)
    }

    @Test func aTrackIsPlayingOnlyWithinItsOwnSpan() {
        let t = track("T", startedSecondsAgo: 100, lasting: 50)
        #expect(t.isPlaying(at: now.addingTimeInterval(-75)))
        #expect(!t.isPlaying(at: now.addingTimeInterval(-101)))
        #expect(!t.isPlaying(at: now.addingTimeInterval(-49)))
    }
}
