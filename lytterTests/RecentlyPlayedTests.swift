//
//  RecentlyPlayedTests.swift
//  lytterTests
//

import Testing
@testable import lytter

/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct RecentlyPlayedTests {

    private func channel(_ id: String) -> DRChannel {
        DRChannel(id: id, title: id.uppercased(), slug: id, type: "Channel", presentationUrl: nil)
    }

    @Test func newestComesFirst() {
        var history = RecentlyPlayed()
        history.record("p1")
        history.record("p3")

        #expect(history.channelIDs == ["p3", "p1"])
    }

    /// The common case is returning to the same two or three stations, so a repeat must
    /// move rather than duplicate.
    @Test func replayingMovesToTheFrontInsteadOfDuplicating() {
        var history = RecentlyPlayed()
        history.record("p1")
        history.record("p3")
        history.record("p1")

        #expect(history.channelIDs == ["p1", "p3"])
    }

    @Test func theListIsCappedAndDropsTheOldest() {
        var history = RecentlyPlayed()
        for i in 0..<(RecentlyPlayed.limit + 5) { history.record("ch\(i)") }

        #expect(history.channelIDs.count == RecentlyPlayed.limit)
        #expect(history.channelIDs.first == "ch\(RecentlyPlayed.limit + 4)")
        #expect(!history.channelIDs.contains("ch0"))
    }

    /// Stored data from an older build, or a truncated write, should not produce two
    /// identical cards.
    @Test func storedDuplicatesAndOverflowAreCleanedOnLoad() {
        let history = RecentlyPlayed(channelIDs: ["p1", "p3", "p1"] + (0..<20).map { "x\($0)" })

        #expect(history.channelIDs.prefix(2) == ["p1", "p3"])
        #expect(history.channelIDs.count == RecentlyPlayed.limit)
    }

    @Test func resolvingKeepsHistoryOrderAndSkipsRetiredChannels() {
        let history = RecentlyPlayed(channelIDs: ["p3", "gone", "p1"])
        let catalogue = [channel("p1"), channel("p3")]

        #expect(history.resolve(in: catalogue).map(\.id) == ["p3", "p1"])
    }

    @Test func anEmptyHistoryResolvesToNothing() {
        #expect(RecentlyPlayed().resolve(in: [channel("p1")]).isEmpty)
        #expect(RecentlyPlayed().isEmpty)
    }
}
