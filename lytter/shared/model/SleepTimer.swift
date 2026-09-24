//
//  SleepTimer.swift
//  lytter
//

import Foundation

/// What the listener asked for. Kept alongside the deadline so the UI can say
/// "end of programme" rather than a bare countdown.
enum SleepTimerMode: Equatable, Hashable {
    case after(minutes: Int)
    case endOfProgramme
}

/// Stops playback at a set time, fading out first.
///
/// A deadline rather than a countdown: a stored `Date` survives the app being backgrounded,
/// suspended and resumed, where a decrementing counter would drift or stall. Everything
/// here is derived from the current time, so there is no state to keep in step.
///
/// No AVFoundation and no timer — the type only answers questions about a moment, which is
/// what makes the behaviour testable without waiting an hour.
struct SleepTimer: Equatable {

    /// How long the fade lasts. Long enough not to feel like a glitch, short enough that
    /// someone still awake can reach for the phone.
    static let fadeDuration: TimeInterval = 20

    let mode: SleepTimerMode
    let firesAt: Date

    init(mode: SleepTimerMode, firesAt: Date) {
        self.mode = mode
        self.firesAt = firesAt
    }

    /// A timer for `mode`, starting now.
    ///
    /// `.endOfProgramme` needs the schedule, so the caller supplies the end time; a
    /// channel with no schedule has nothing to count down to and gets `nil`.
    init?(mode: SleepTimerMode, from now: Date, programmeEnd: Date? = nil) {
        switch mode {
        case .after(let minutes):
            guard minutes > 0 else { return nil }
            self.init(mode: mode, firesAt: now.addingTimeInterval(TimeInterval(minutes) * 60))
        case .endOfProgramme:
            guard let programmeEnd, programmeEnd > now else { return nil }
            self.init(mode: mode, firesAt: programmeEnd)
        }
    }

    /// Seconds left, never negative.
    func remaining(at date: Date) -> TimeInterval {
        max(firesAt.timeIntervalSince(date), 0)
    }

    /// Whether playback should now be stopped.
    func hasFired(at date: Date) -> Bool {
        date >= firesAt
    }

    /// What to multiply the player's volume by, ramping from 1 to 0 across the last
    /// `fadeDuration` seconds.
    ///
    /// Clamped at both ends: a timer set for less than the fade duration starts partway
    /// down rather than jumping to full volume, and nothing here ever returns a value
    /// outside 0...1 for AVPlayer to reject.
    func volumeMultiplier(at date: Date) -> Float {
        let left = remaining(at: date)
        guard left < Self.fadeDuration else { return 1 }
        return Float(max(left, 0) / Self.fadeDuration)
    }
}
