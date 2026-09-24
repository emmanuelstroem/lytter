//
//  InterruptionStateTests.swift
//  lytterTests
//

import Testing
@testable import lytter

/// Playback could start on its own. An interruption that ended without `.shouldResume`
/// left the resume flag set, and the route-change handler resumed on
/// `.newDeviceAvailable` — so plugging in headphones long afterwards started the radio,
/// with nothing on screen connecting it to the call that set the flag.
struct InterruptionStateTests {

    /// The reported sequence, and the reason the bug was hard to attribute: the trigger is
    /// arbitrarily far from the cause.
    @Test func anInterruptionThatEndsWithoutResumeLeavesNothingBehind() {
        var state = InterruptionState()

        state.began(wasPlaying: true)                            // a call arrives
        #expect(state.shouldResumeWhenInterruptionEnds)

        let resumes = state.ended(systemAllowsResume: false)     // the call ends, no resume

        #expect(!resumes)
        #expect(!state.shouldResumeWhenInterruptionEnds,
                "a later route change would find this set and start playing")
    }

    @Test func anInterruptionThatEndsWithResumeResumesOnce() {
        var state = InterruptionState()
        state.began(wasPlaying: true)

        let first = state.ended(systemAllowsResume: true)
        let second = state.ended(systemAllowsResume: true)

        #expect(first)
        #expect(!second, "a second end event must not resume again")
    }

    /// An interruption arriving while already paused must not start playback when it ends.
    @Test func anInterruptionWhilePausedNeverResumes() {
        var state = InterruptionState()
        state.began(wasPlaying: false)

        #expect(!state.shouldResumeWhenInterruptionEnds)
        let resumes = state.ended(systemAllowsResume: true)
        #expect(!resumes)
    }

    /// Pressing pause during a call, or unplugging headphones, settles the question: the
    /// interruption ending later must not override it.
    @Test func aDeliberatePauseDuringAnInterruptionWins() {
        var state = InterruptionState()
        state.began(wasPlaying: true)

        state.playbackSettledDeliberately()
        let resumes = state.ended(systemAllowsResume: true)

        #expect(!resumes)
    }

    @Test func startingAChannelClearsAnyPendingIntent() {
        var state = InterruptionState()
        state.began(wasPlaying: true)

        state.playbackSettledDeliberately()   // play(url:) does this

        #expect(!state.shouldResumeWhenInterruptionEnds)
    }

    @Test func aFreshStateResumesNothing() {
        var state = InterruptionState()
        let resumes = state.ended(systemAllowsResume: true)

        #expect(!state.shouldResumeWhenInterruptionEnds)
        #expect(!resumes)
    }
}
