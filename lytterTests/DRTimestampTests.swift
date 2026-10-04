//
//  DRTimestampTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// Programme and track times are parsed once, when decoded, rather than on every read.
/// What DR sends and what the disk cache holds must not change with it: the times are
/// still bare strings under `startTime`, `endTime` and `playedTime`.
@MainActor
struct DRTimestampTests {

    /// 20:49:10 UTC on 2026-10-02.
    private let instant = Date(timeIntervalSince1970: 1_790_974_150)

    @Test func parsesWhenMade() {
        #expect(DRTimestamp("2026-10-02T20:49:10+00:00").date == instant)
        #expect(DRTimestamp("not a date").date == nil)
    }

    /// The fields DR's track list sends for one track.
    @Test func aTrackFromDRHasItsPlayedDate() throws {
        let json = """
            {"type": "Track", "durationMilliseconds": 200000,
             "playedTime": "2026-10-02T20:49:10+00:00", "musicUrl": "", "trackUrn": "urn:t",
             "classical": false, "title": "Song", "description": "Artist"}
            """
        let track = try JSONDecoder().decode(DRTrack.self, from: Data(json.utf8))

        #expect(track.playedTime == "2026-10-02T20:49:10+00:00")
        #expect(track.playedDate == instant)
    }

    @Test func anEpisodeRoundTripsWithItsTimesAsStrings() throws {
        let episode = DREpisode(
            type: "Episode", learnId: "e", durationMilliseconds: 0, categories: nil,
            productionNumber: nil, startTime: "2026-10-02T20:49:10+00:00",
            endTime: "2026-10-02T22:03:00+00:00", presentationUrl: nil, order: 0,
            previousId: nil, nextId: nil, series: nil,
            channel: DRChannel(id: "urn:p1", title: "P1", slug: "p1", type: "Channel",
                               presentationUrl: nil),
            audioAssets: nil, isAvailableOnDemand: false, hasVideo: false,
            explicitContent: false, id: "e", slug: "e", title: "e", description: nil,
            imageAssets: nil, episodeNumber: nil, seasonNumber: nil)

        let data = try JSONEncoder().encode(episode)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["startTime"] as? String == "2026-10-02T20:49:10+00:00")
        #expect(object["endTime"] as? String == "2026-10-02T22:03:00+00:00")

        let decoded = try JSONDecoder().decode(DREpisode.self, from: data)
        #expect(decoded == episode)
        #expect(decoded.startDate == instant)
        #expect(decoded.endDate == instant.addingTimeInterval(4430))
    }
}
