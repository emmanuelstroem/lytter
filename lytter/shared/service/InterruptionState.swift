//
//  InterruptionState.swift
//  lytter
//

import Foundation

/// Whether playback was stopped by the system and should start again when that ends.
///
/// This was a bare `Bool` on `AudioPlayerService`, set when an interruption began and
/// cleared in some paths but not others. A call that ended without `.shouldResume` left it
/// set, and the route-change handler resumed on `.newDeviceAvailable` — so plugging in
/// headphones an hour later started the radio unprompted, with nothing on screen to
/// connect the two.
///
/// The rule the type enforces is that the intent expires the moment the interruption
/// resolves, whether or not it resulted in playback. It is a value type with no
/// dependency on AVFoundation so the sequences can be tested directly.
struct InterruptionState: Equatable {

    /// Whether an interruption is outstanding that playback should resume after.
    private(set) var shouldResumeWhenInterruptionEnds = false

    /// The system interrupted playback — a call, an alarm, another app taking the session.
    ///
    /// Only worth remembering if something was actually playing; an interruption that
    /// arrives while paused must not start playback when it ends.
    mutating func began(wasPlaying: Bool) {
        shouldResumeWhenInterruptionEnds = wasPlaying
    }

    /// The interruption ended. Returns whether playback should resume.
    ///
    /// Clears the flag either way. That is the fix: the interruption is over, so the
    /// intent it recorded has expired, and a later unrelated event must not find it
    /// still set.
    mutating func ended(systemAllowsResume: Bool) -> Bool {
        defer { shouldResumeWhenInterruptionEnds = false }
        return systemAllowsResume && shouldResumeWhenInterruptionEnds
    }

    /// Playback changed for a reason that is not an interruption — the listener pressed
    /// pause, a new channel started, or the output device went away.
    ///
    /// Apple's guidance is not to restart audio when a route becomes available again, so
    /// an unplugged device clears the intent rather than deferring it.
    mutating func playbackSettledDeliberately() {
        shouldResumeWhenInterruptionEnds = false
    }
}
