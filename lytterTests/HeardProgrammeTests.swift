//
//  HeardProgrammeTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// Rewinding across a programme start has to show the programme being heard, which
/// `/schedules/all/now` does not carry: it comes from the schedule snapshot, fetched once
/// and retried after a failure.
///
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct HeardProgrammeTests {

    /// 22:03 UTC: the P1 boundary this was written against.
    private let boundary = ISO8601DateFormatter().date(from: "2026-10-02T22:03:00Z")!

    private func programme(_ id: String, start: String, end: String) -> DREpisode {
        DREpisode(type: "Episode", learnId: id, durationMilliseconds: 0, categories: nil,
                  productionNumber: nil, startTime: start, endTime: end, presentationUrl: nil,
                  order: 0, previousId: nil, nextId: nil, series: nil,
                  channel: DRChannel(id: "urn:p1", title: "P1", slug: "p1", type: "Channel",
                                     presentationUrl: nil),
                  audioAssets: nil, isAvailableOnDemand: false, hasVideo: false,
                  explicitContent: false, id: id, slug: id, title: id, description: nil,
                  imageAssets: nil, episodeNumber: nil, seasonNumber: nil)
    }

    private var onAir: DREpisode {
        programme("late", start: "2026-10-02T22:03:00+00:00", end: "2026-10-03T00:00:00+00:00")
    }
    private var before: DREpisode {
        programme("evening", start: "2026-10-02T20:03:00+00:00", end: "2026-10-02T22:03:00+00:00")
    }

    // MARK: Which programme

    @Test func fiveMinutesBehindAcrossTheBoundaryIsTheEarlierProgramme() {
        let heard = DRServiceManager.heardProgram(in: [onAir, before],
                                                  at: boundary.addingTimeInterval(5 * 60 - 10 * 60))
        #expect(heard?.id == "evening")
    }

    @Test func behindButStillAfterTheStartIsTheProgrammeOnAir() {
        let heard = DRServiceManager.heardProgram(in: [onAir, before],
                                                  at: boundary.addingTimeInterval(60))
        #expect(heard?.id == "late")
    }

    // MARK: Whether to fetch

    private func needs(listeningAt date: Date, have snapshot: DRServiceManager.HeardSnapshot?,
                       now: Date? = nil) -> Bool {
        DRServiceManager.needsHeardSnapshot(listeningAt: date, liveProgrammeStart: boundary,
                                            channelID: "urn:p1", have: snapshot,
                                            now: now ?? boundary.addingTimeInterval(300))
    }

    @Test func notNeededWhileStillInsideTheProgrammeOnAir() {
        #expect(!needs(listeningAt: boundary.addingTimeInterval(60), have: nil))
    }

    @Test func neededOnceEarlierThanTheProgrammeOnAir() {
        #expect(needs(listeningAt: boundary.addingTimeInterval(-60), have: nil))
    }

    @Test func notFetchedAgainOnceInHand() {
        let snapshot = DRServiceManager.HeardSnapshot(channelID: "urn:p1", episodes: [before],
                                                      fetchedAt: boundary)
        #expect(!needs(listeningAt: boundary.addingTimeInterval(-60), have: snapshot))
    }

    /// A failed fetch yields an empty list. It is retried, but not on every second's tick.
    @Test func aFailedFetchIsRetriedAfterTheInterval() {
        let failed = DRServiceManager.HeardSnapshot(channelID: "urn:p1", episodes: [],
                                                    fetchedAt: boundary)
        let early = boundary.addingTimeInterval(DRServiceManager.heardSnapshotRetryInterval - 1)
        let late = boundary.addingTimeInterval(DRServiceManager.heardSnapshotRetryInterval)
        #expect(!needs(listeningAt: boundary.addingTimeInterval(-60), have: failed, now: early))
        #expect(needs(listeningAt: boundary.addingTimeInterval(-60), have: failed, now: late))
    }

    @Test func anotherChannelsSnapshotDoesNotCount() {
        let other = DRServiceManager.HeardSnapshot(channelID: "urn:p2", episodes: [before],
                                                   fetchedAt: boundary)
        #expect(needs(listeningAt: boundary.addingTimeInterval(-60), have: other))
    }
}
