//
//  ScheduleFreshnessTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// A programme that has ended is never shown as on air, and the schedule is fetched again
/// as programmes end rather than once at launch (P13).
@MainActor
struct ScheduleFreshnessTests {

    /// 22:03 UTC, a programme boundary.
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

    private var evening: DREpisode {
        programme("evening", start: "2026-10-02T20:03:00+00:00", end: "2026-10-02T22:03:00+00:00")
    }
    private var late: DREpisode {
        programme("late", start: "2026-10-02T22:03:00+00:00", end: "2026-10-03T00:00:00+00:00")
    }

    private func at(_ seconds: TimeInterval) -> Date { boundary.addingTimeInterval(seconds) }

    // MARK: - What is on air

    @Test func theProgrammeOnAirIsLive() {
        #expect(DRServiceManager.liveProgram(in: [evening, late], at: at(60))?.id == "late")
    }

    /// The bug: with only an ended programme cached, it was shown as on air.
    @Test func anEndedProgrammeIsNeverLive() {
        #expect(DRServiceManager.liveProgram(in: [evening], at: at(60)) == nil)
        #expect(DRServiceManager.liveProgram(in: [evening], at: at(24 * 60 * 60)) == nil)
    }

    @Test func aProgrammeNotYetStartedIsNotLive() {
        #expect(DRServiceManager.liveProgram(in: [late], at: at(-60)) == nil)
    }

    /// Without times there is nothing to say it has ended, so it stands.
    @Test func aProgrammeWithoutTimesStillShows() {
        let undated = programme("undated", start: "", end: "")
        #expect(DRServiceManager.liveProgram(in: [evening, undated], at: at(60))?.id == "undated")
    }

    // MARK: - When to fetch again

    @Test func aFreshScheduleWithNothingEndedIsLeftAlone() {
        #expect(!DRServiceManager.needsScheduleRefresh([late], lastFetched: at(0), now: at(60)))
    }

    @Test func anEndedProgrammeCallsForARefresh() {
        #expect(DRServiceManager.needsScheduleRefresh([evening, late], lastFetched: at(-60),
                                                      now: at(30)))
    }

    @Test func aScheduleNeverFetchedOrTooOldCallsForARefresh() {
        #expect(DRServiceManager.needsScheduleRefresh([late], lastFetched: nil, now: at(60)))
        #expect(DRServiceManager.needsScheduleRefresh([late], lastFetched: at(0),
                                                      now: at(11 * 60)))
    }

    @Test func theNextRefreshIsJustAfterTheSoonestEnd() {
        // `late` ends at midnight; ten minutes before, the wait is ten minutes and change —
        // which the upper bound holds to ten.
        let midnight = at(117 * 60)
        #expect(DRServiceManager.scheduleRefreshDelay([late], now: midnight.addingTimeInterval(-5 * 60))
                == 5 * 60 + 5)
    }

    @Test func theRefreshWaitIsBounded() {
        // Nothing ending for hours: ten minutes. Something ending in a second: a minute.
        #expect(DRServiceManager.scheduleRefreshDelay([late], now: at(60)) == 10 * 60)
        #expect(DRServiceManager.scheduleRefreshDelay([late], now: at(117 * 60 - 1)) == 60)
        #expect(DRServiceManager.scheduleRefreshDelay([], now: at(0)) == 10 * 60)
    }
}
