//
//  ProgrammeProgressTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// The full player's progress bar was driven by two `@State` values that nothing ever
/// wrote, so it sat permanently at zero. It now reports progress through the programme on
/// air, which is arithmetic worth pinning rather than re-checking against a screenshot.
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION
/// = MainActor, so the types under test are main-actor isolated by inference. Swift 6
/// rejects calling them from a nonisolated suite.
@MainActor
struct ProgrammeProgressTests {

    /// 13:30–14:03, the P1 slot this was first verified against.
    private func episode(
        start: String = "2026-09-24T11:30:00+00:00",
        end: String = "2026-09-24T12:03:00+00:00"
    ) -> DREpisode {
        DREpisode(
            type: "Episode",
            learnId: "x",
            durationMilliseconds: 1_980_000,
            categories: nil,
            productionNumber: nil,
            startTime: start,
            endTime: end,
            presentationUrl: nil,
            order: 0,
            previousId: nil,
            nextId: nil,
            series: nil,
            channel: DRChannel(
                id: "urn:dr:radio:channel:p1",
                title: "P1",
                slug: "p1",
                type: "Channel",
                presentationUrl: nil
            ),
            audioAssets: nil,
            isAvailableOnDemand: false,
            hasVideo: false,
            explicitContent: false,
            id: "urn:dr:radio:episode:test",
            slug: "test",
            title: "Test",
            description: nil,
            imageAssets: nil,
            episodeNumber: nil,
            seasonNumber: nil
        )
    }

    private func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    @Test func progressIsZeroAtTheStartAndOneAtTheEnd() {
        let e = episode()
        #expect(e.progress(at: date("2026-09-24T11:30:00+00:00")) == 0)
        #expect(e.progress(at: date("2026-09-24T12:03:00+00:00")) == 1)
    }

    /// The case caught on screen: 13.56 local into a 13.30–14.03 slot is 26 of 33 minutes.
    @Test func progressPartWayThrough() throws {
        let p = try #require(episode().progress(at: date("2026-09-24T11:56:00+00:00")))
        #expect(abs(p - 26.0 / 33.0) < 0.001)
    }

    /// Clamped, because the schedule can be stale: `/schedules/all/now` is cached for ten
    /// minutes, so a programme can be reported as current after it has ended.
    @Test func progressIsClampedOutsideTheSlot() {
        let e = episode()
        #expect(e.progress(at: date("2026-09-24T10:00:00+00:00")) == 0)
        #expect(e.progress(at: date("2026-09-24T23:00:00+00:00")) == 1)
    }

    @Test func aZeroLengthSlotHasNoProgress() {
        let e = episode(start: "2026-09-24T11:30:00+00:00", end: "2026-09-24T11:30:00+00:00")
        #expect(e.progress(at: date("2026-09-24T11:30:00+00:00")) == nil)
    }

    @Test func unparseableTimesHaveNoProgress() {
        let e = episode(start: "not a date", end: "also not a date")
        #expect(e.progress(at: Date()) == nil)
        #expect(e.minutesRemaining(at: Date()) == nil)
    }

    @Test func minutesRemainingCountsDownAndStopsAtZero() {
        let e = episode()
        #expect(e.minutesRemaining(at: date("2026-09-24T11:56:00+00:00")) == 7)
        #expect(e.minutesRemaining(at: date("2026-09-24T23:00:00+00:00")) == 0)
    }
}
