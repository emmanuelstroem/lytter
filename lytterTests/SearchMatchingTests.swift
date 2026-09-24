//
//  SearchMatchingTests.swift
//  lytterTests
//

import Testing
@testable import lytter

/// Search has to do two things that pull against each other: show one entry per station, and
/// still find a district. P4 is ten channels and one result, but typing "Bornholm" must
/// reach it.
///
/// These pin that bargain against the channel list DR actually serves.
///
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct SearchMatchingTests {

    private func channel(_ title: String) -> DRChannel {
        DRChannel(id: title.lowercased(), title: title, slug: title.lowercased(),
                  type: "Channel", presentationUrl: nil)
    }

    /// Every channel title DR served on 2026-09-24.
    private static let live = [
        "P1", "P2", "P3",
        "P4 Bornholm", "P4 Esbjerg", "P4 Fyn", "P4 København", "P4 Midt & Vest",
        "P4 Nordjylland", "P4 Sjælland", "P4 Syd", "P4 Trekanten", "P4 Østjylland",
        "P5 Bornholm", "P5 Esbjerg", "P5 Fyn", "P5 København", "P5 Midt & Vest",
        "P5 Nordjylland", "P5 Sjælland", "P5 Syd", "P5 Trekanten", "P5 Østjylland",
        "P6", "P8"
    ]

    /// What the search screen shows for a given query.
    private func results(for query: String,
                         nowPlaying: @escaping (DRChannel) -> String? = { _ in nil }) -> [String] {
        GroupedChannel.grouped(from: Self.live.map(channel))
            .filter { $0.matches(query, nowPlaying: nowPlaying) }
            .map(\.name)
    }

    // MARK: - No duplicates

    @Test func everyStationAppearsOnce() {
        let all = results(for: "")

        #expect(all == ["P1", "P2", "P3", "P4", "P5", "P6", "P8"])
        #expect(all.count == Set(all).count, "a station listed twice is the bug this fixes")
    }

    /// The flat list had ten P4 entries with the same artwork and the same name, which buried
    /// every other station below them.
    @Test func aStationWithTenDistrictsIsOneResult() {
        #expect(results(for: "P4") == ["P4"])
    }

    // MARK: - Districts are still reachable

    @Test func aDistrictNameFindsTheStationsThatBroadcastIt() {
        #expect(results(for: "København") == ["P4", "P5"],
                "grouping must not cost reach — both stations serve that region")
    }

    @Test func aDistrictUniqueEnoughStillMatches() {
        #expect(results(for: "Bornholm") == ["P4", "P5"])
    }

    @Test func aMultiWordDistrictIsFoundByItsFirstWord() {
        #expect(results(for: "Midt") == ["P4", "P5"])
    }

    @Test func matchingIgnoresCase() {
        #expect(results(for: "kØBENHAVN") == ["P4", "P5"])
    }

    // MARK: - What is on air

    /// Closer to how someone looks for live radio: they remember the programme, not the
    /// station it is on.
    @Test func aProgrammeOnAirFindsItsStation() {
        let onAir: (DRChannel) -> String? = { $0.name == "P1" ? "Orientering" : nil }

        #expect(results(for: "orientering", nowPlaying: onAir) == ["P1"])
    }

    // MARK: - Negative control

    @Test func somethingNobodyBroadcastsFindsNothing() {
        #expect(results(for: "zzzz").isEmpty,
                "if this ever passes with results, the filter is not filtering")
    }
}
