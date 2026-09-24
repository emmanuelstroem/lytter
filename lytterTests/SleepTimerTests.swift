//
//  SleepTimerTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor,
/// so the types under test are main-actor isolated by inference.
@MainActor
struct SleepTimerTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func at(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    // MARK: - Deadlines

    @Test func aDurationCountsFromWhenItWasSet() throws {
        let timer = try #require(SleepTimer(mode: .after(minutes: 30), from: start))

        #expect(timer.remaining(at: start) == 1800)
        #expect(timer.remaining(at: at(600)) == 1200)
        #expect(!timer.hasFired(at: at(1799)))
        #expect(timer.hasFired(at: at(1800)))
    }

    /// Never negative: the tick that notices expiry can arrive late, and a negative
    /// remaining time would render as nonsense.
    @Test func remainingStopsAtZero() throws {
        let timer = try #require(SleepTimer(mode: .after(minutes: 1), from: start))

        #expect(timer.remaining(at: at(10_000)) == 0)
    }

    @Test func endOfProgrammeUsesTheScheduleNotADuration() throws {
        let programmeEnds = at(2_400)
        let timer = try #require(
            SleepTimer(mode: .endOfProgramme, from: start, programmeEnd: programmeEnds))

        #expect(timer.firesAt == programmeEnds)
        #expect(timer.mode == .endOfProgramme)
    }

    /// A channel with no schedule has nothing to count down to, and a programme that has
    /// already ended would fire instantly.
    @Test func endOfProgrammeNeedsAFutureEnd() {
        #expect(SleepTimer(mode: .endOfProgramme, from: start, programmeEnd: nil) == nil)
        #expect(SleepTimer(mode: .endOfProgramme, from: start, programmeEnd: at(-60)) == nil)
    }

    @Test func aZeroLengthTimerIsRejected() {
        #expect(SleepTimer(mode: .after(minutes: 0), from: start) == nil)
    }

    // MARK: - Fade

    @Test func volumeIsUntouchedUntilTheFadeBegins() throws {
        let timer = try #require(SleepTimer(mode: .after(minutes: 30), from: start))

        #expect(timer.volumeMultiplier(at: start) == 1)
        #expect(timer.volumeMultiplier(at: at(1_700)) == 1)
    }

    @Test func volumeRampsToSilenceOverTheFade() throws {
        let timer = try #require(SleepTimer(mode: .after(minutes: 30), from: start))
        let fadeStarts = 1800 - SleepTimer.fadeDuration

        #expect(timer.volumeMultiplier(at: at(fadeStarts)) == 1)
        #expect(abs(timer.volumeMultiplier(at: at(fadeStarts + 10)) - 0.5) < 0.001)
        #expect(timer.volumeMultiplier(at: at(1800)) == 0)
    }

    /// Past the deadline the multiplier stays at zero rather than going negative — AVPlayer
    /// rejects a negative volume.
    @Test func volumeNeverGoesBelowZero() throws {
        let timer = try #require(SleepTimer(mode: .after(minutes: 1), from: start))

        #expect(timer.volumeMultiplier(at: at(5_000)) == 0)
    }

    /// A timer shorter than the fade starts partway down instead of jumping to full volume
    /// and then cutting.
    @Test func aTimerShorterThanTheFadeStartsPartwayDown() throws {
        let timer = try #require(SleepTimer(mode: .endOfProgramme, from: start,
                                            programmeEnd: at(10)))

        #expect(abs(timer.volumeMultiplier(at: start) - 0.5) < 0.001)
    }
}
