//
//  PlayingMarkAnimationTests.swift
//  lytterTests
//

import Testing
@testable import lytter

/// The playing mark pulses while a station plays, and holds still under Reduce Motion (F38).
///
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct PlayingMarkAnimationTests {

    /// Reduce Motion draws the rings at rest, fully opaque, whatever the time.
    @Test func atRestTheRingsSitAtTheirRadii() {
        #expect(PlayingMark.rings(at: nil)
                == PlayingMark.ringRadii.map { .init(radius: $0, opacity: 1) })
    }

    /// Animated, the rings are somewhere else a quarter of a period later — it moves.
    @Test func theRingsMoveOverAPeriod() {
        #expect(PlayingMark.rings(at: 0) != PlayingMark.rings(at: 0.25))
    }

    /// And come back to where they were a period later, so the pulse repeats rather than
    /// drifts.
    @Test func thePulseRepeatsEveryPeriod() {
        for (now, later) in zip(PlayingMark.rings(at: 0.3), PlayingMark.rings(at: 1.3)) {
            #expect(abs(now.radius - later.radius) < 1e-9)
            #expect(abs(now.opacity - later.opacity) < 1e-9)
        }
    }

    /// At their widest the rings stay inside the mark's box, so the pulse never spills into
    /// the name beside it; and the inner ring never reaches the outer one.
    @Test func theRingsStayInsideTheMark() {
        for step in 0..<100 {
            let rings = PlayingMark.rings(at: Double(step) / 100)
            #expect(rings.allSatisfy { $0.radius < 1 && $0.opacity > 0 })
            #expect(rings[0].radius < rings[1].radius)
        }
    }
}
