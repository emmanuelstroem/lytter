//
//  AudioSessionPolicyTests.swift
//  lytterTests
//

import Foundation
import Testing
#if os(iOS) || os(tvOS) || os(visionOS)
import AVFAudio
#endif
@testable import lytter

/// A call taken on the handset should leave the radio playing on an AirPlay speaker (F55).
/// What makes that happen is a session setting, and nothing fails when it is wrong: the
/// radio just stops for every call, as it did while play and resume asked for the default
/// route-sharing policy and only the interruption path asked for long-form. No simulator
/// can place a call, so these pin down the settings and the resume; the call itself is the
/// device checklist in docs/AUDIO-AND-CALLS.md.
///
/// Serialized: the session and the notification centre are shared, and a fake interruption
/// posted by one test reaches every player alive at the time.
@MainActor
@Suite(.serialized)
struct AudioSessionPolicyTests {

    /// The plist key is what the AirPlay picker goes by before the first play has set the
    /// policy on the session. Read from the Info.plist that shipped.
    @Test func builtAppAsksForLongFormAudioFromLaunch() {
        let policy = Bundle.main.object(forInfoDictionaryKey: "AVInitialRouteSharingPolicy") as? String
        #expect(policy == "LongFormAudio")
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
    /// Nothing listens on the discard port, so the stream fails at once and plays nothing.
    private static let unplayable = URL(string: "http://127.0.0.1:9/live.m3u8")!

    /// Polls, letting the main actor run meanwhile: the session is set on a queue of its
    /// own, and the resume after an interruption is half a second behind the event.
    private func eventually(within seconds: Double = 2, _ condition: () -> Bool) async throws -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while !condition() {
            if Date() > deadline { return false }
            try await Task.sleep(for: .milliseconds(50))
        }
        return true
    }

    /// Starts from the settings this replaced, so a pass shows play set them rather than
    /// that something earlier left them that way.
    @Test func playingAsksForLongFormAudio() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, policy: .default)
        #if os(iOS)
        try session.setPrefersNoInterruptionsFromSystemAlerts(false)
        #endif

        let player = AudioPlayerService()
        player.play(url: Self.unplayable)
        defer { player.stop() }

        #expect(try await eventually { session.routeSharingPolicy == .longFormAudio },
                "the session is still \(session.routeSharingPolicy.rawValue), not long-form")
        #if os(iOS)
        #expect(session.prefersNoInterruptionsFromSystemAlerts,
                "a ringing call would still stop the radio")
        #endif
    }

    /// The resume after a call is the listener's own Resume. It used to call play() on the
    /// player directly, which left `wantsPlayback` false — so a stream that stalled after
    /// the call was never recovered — and skipped the reload at live for a call longer
    /// than the window.
    @Test func resumingAfterACallIsAResume() async throws {
        let player = AudioPlayerService()
        player.play(url: Self.unplayable)
        defer { player.stop() }
        player.isPlaying = true

        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        #expect(!player.wantsPlayback, "the call should have paused it")

        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                       AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue])

        #expect(try await eventually { player.wantsPlayback },
                "the call ended with shouldResume, but the listener's intent was not restored")
    }
    #endif
}
