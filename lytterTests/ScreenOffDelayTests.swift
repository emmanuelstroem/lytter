//
//  ScreenOffDelayTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// When Screen Off (F43) blacks the screen out: after the chosen delay, only while playing,
/// never when switched off.
@MainActor
struct ScreenOffDelayTests {

    private let touched = Date(timeIntervalSinceReferenceDate: 1_000)

    @Test func blacksOutTheDelayAfterTheLastTouch() {
        #expect(ScreenOffDelay.thirtySeconds.blackoutTime(after: touched, isPlaying: true)
                == touched.addingTimeInterval(30))
        #expect(ScreenOffDelay.fiveMinutes.blackoutTime(after: touched, isPlaying: true)
                == touched.addingTimeInterval(300))
    }

    /// A paused app is the system's to dim and lock, as any other app is.
    @Test func neverWhileNothingPlays() {
        #expect(ScreenOffDelay.thirtySeconds.blackoutTime(after: touched, isPlaying: false) == nil)
    }

    @Test func neverWhenSwitchedOff() {
        #expect(ScreenOffDelay.never.blackoutTime(after: touched, isPlaying: true) == nil)
    }

    /// The raw values are the stored format: changing one would quietly reset everyone's
    /// choice to the default.
    @Test func storedAsSeconds() {
        #expect(ScreenOffDelay.allCases.map(\.rawValue) == [0, 30, 60, 120, 300])
        #expect(ScreenOffDelay.default == .thirtySeconds)
    }
}
