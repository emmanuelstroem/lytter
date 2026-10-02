//
//  DRDateTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// Every date in the app goes through `DRDate`, now one shared formatter rather than one per
/// access. These pin the forms DR sends.
///
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct DRDateTests {

    @Test func parsesAnOffsetTimestamp() {
        #expect(DRDate.parse("2026-10-02T20:49:10+00:00") == Date(timeIntervalSince1970: 1_790_974_150))
    }

    @Test func parsesAUTCTimestamp() {
        #expect(DRDate.parse("2026-10-02T20:49:10Z") == Date(timeIntervalSince1970: 1_790_974_150))
    }

    /// Danish summer time: the same instant as the UTC form above.
    @Test func honoursANonZeroOffset() {
        #expect(DRDate.parse("2026-10-02T22:49:10+02:00") == Date(timeIntervalSince1970: 1_790_974_150))
    }

    @Test func rejectsWhatIsNotATimestamp() {
        #expect(DRDate.parse("") == nil)
        #expect(DRDate.parse("not a date") == nil)
    }
}
