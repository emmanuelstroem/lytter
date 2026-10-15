//
//  TrackPollingTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// The live track is asked for again just after the song ends, and with no song playing a
/// little later each time — 15 s, 30 s, then a minute — rather than every 15 s, which cost
/// a talk channel 240 requests a listening hour.
@MainActor
struct TrackPollingTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func track(_ title: String, startedSecondsAgo: TimeInterval, lasting: TimeInterval) -> DRTrack {
        let start = ISO8601DateFormatter().string(from: now.addingTimeInterval(-startedSecondsAgo))
        return DRTrack(type: "Track", durationMilliseconds: Int(lasting * 1000), playedTime: start,
                       musicUrl: "", trackUrn: "urn:\(title)", classical: false, roles: nil,
                       title: title, description: "")
    }

    /// 60 s into a 200 s song: wake 5 s after its last 140.
    @Test func aSongPlayingIsAskedAboutJustAfterItEnds() {
        var polling = TrackPolling()
        let song = track("Song", startedSecondsAgo: 60, lasting: 200)
        #expect(polling.delay(heard: song, known: [song], secondsBehindLive: 0, now: now) == 145)
        #expect(polling.idlePolls == 0)
    }

    /// Talk: each poll in a row that finds no song waits longer, and the last wait holds.
    @Test func withNoSongTheWaitGrowsToAMinute() {
        var polling = TrackPolling()
        let waits = (0..<5).map { _ in
            polling.delay(heard: nil, known: [], secondsBehindLive: 0, now: now)
        }
        #expect(waits == [15, 30, 60, 60, 60])
    }

    /// A song that has ended is no song.
    @Test func anEndedSongCountsAsNone() {
        var polling = TrackPolling()
        let ended = track("Ended", startedSecondsAgo: 300, lasting: 200)
        #expect(polling.delay(heard: ended, known: [ended], secondsBehindLive: 0, now: now) == 15)
        #expect(polling.idlePolls == 1)
    }

    /// A song appearing starts the count again, so the next gap is asked about after 15 s.
    @Test func aSongAppearingStartsTheCountAgain() {
        var polling = TrackPolling()
        for _ in 0..<4 { _ = polling.delay(heard: nil, known: [], secondsBehindLive: 0, now: now) }
        let song = track("Song", startedSecondsAgo: 10, lasting: 100)
        #expect(polling.delay(heard: song, known: [song], secondsBehindLive: 0, now: now) == 95)
        #expect(polling.idlePolls == 0)
        #expect(polling.delay(heard: nil, known: [song], secondsBehindLive: 0, now: now) == 15)
    }

    /// 120 s behind live, the song heard ends 30 s from what is being heard, not 90 s ago.
    @Test func behindLiveTheSongHeardIsTheOneWaitedOn() {
        var polling = TrackPolling()
        let heard = track("Heard", startedSecondsAgo: 250, lasting: 160)
        #expect(polling.delay(heard: heard, known: [heard], secondsBehindLive: 120, now: now) == 35)
    }

    /// Behind live in a gap, the next song is already listed: wake as it starts, not a minute
    /// after. With the next song further off than the back-off, the back-off still wins.
    @Test func behindLiveTheNextListedSongEndsTheWait() {
        var polling = TrackPolling()
        for _ in 0..<3 { _ = polling.delay(heard: nil, known: [], secondsBehindLive: 0, now: now) }
        // Heard at now − 300; "Next" started at now − 280, 20 s on from there.
        let next = track("Next", startedSecondsAgo: 280, lasting: 200)
        #expect(polling.delay(heard: nil, known: [next], secondsBehindLive: 300, now: now) == 21)
        // Started at now − 100: 200 s on from what is heard, past the minute.
        let later = track("Later", startedSecondsAgo: 100, lasting: 200)
        #expect(polling.delay(heard: nil, known: [later], secondsBehindLive: 300, now: now) == 60)
    }
}
