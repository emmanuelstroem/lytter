//
//  OnDemandTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// Catch-up listening (F16): which broadcasts can be played back, from which file, how the
/// schedule sheet's day is put together, and that choosing a station leaves a recording.
@MainActor
struct OnDemandTests {

    private let p1 = DRChannel(id: "urn:p1", title: "P1", slug: "p1", type: "Channel",
                               presentationUrl: nil)

    /// 10:00 UTC on 2026-10-05.
    private let now = Date(timeIntervalSince1970: 1_791_194_400)

    private static let liveAssets = [
        DRAudioAsset(type: "Audio", target: "Stream", isStreamLive: true, format: "HLS",
                     bitrate: 0, url: "https://live/hls"),
        DRAudioAsset(type: "Audio", target: "Stream", isStreamLive: true, format: "ICY",
                     bitrate: 192, url: "https://live/icy")
    ]

    /// In the order DR sends them: the progressive files first, HLS last.
    private static let recordedAssets = [
        DRAudioAsset(type: "Audio", target: "Progressive", isStreamLive: false, format: "mp4",
                     bitrate: 64, url: "https://ondemand/64.mp4"),
        DRAudioAsset(type: "Audio", target: "Progressive", isStreamLive: false, format: "mp3",
                     bitrate: 192, url: "https://ondemand/192.mp3"),
        DRAudioAsset(type: "Audio", target: "Stream", isStreamLive: false, format: "HLS",
                     bitrate: 0, url: "https://ondemand/hls")
    ]

    private func episode(startingMinutesFromNow offset: Double, minutes: Double = 60,
                         assets: [DRAudioAsset]? = recordedAssets, onDemand: Bool = true,
                         id: String = "urn:e") -> DREpisode {
        let start = now.addingTimeInterval(offset * 60)
        let format = ISO8601DateFormatter()
        return DREpisode(
            type: "Episode", learnId: "", durationMilliseconds: Int(minutes * 60_000),
            categories: nil, productionNumber: nil,
            startTime: format.string(from: start),
            endTime: format.string(from: start.addingTimeInterval(minutes * 60)),
            presentationUrl: nil, order: 0, previousId: nil, nextId: nil, series: nil,
            channel: p1, audioAssets: assets, isAvailableOnDemand: onDemand, hasVideo: nil,
            explicitContent: nil, id: id, slug: id, title: id, description: nil,
            imageAssets: nil, episodeNumber: nil, seasonNumber: nil)
    }

    // MARK: - Which file

    @Test func theRecordingPrefersHLS() {
        #expect(episode(startingMinutesFromNow: -120).onDemandStreamURL == "https://ondemand/hls")
    }

    @Test func withoutHLSAProgressiveFileIsUsed() {
        let progressive = Array(Self.recordedAssets.prefix(2))
        #expect(episode(startingMinutesFromNow: -120, assets: progressive).onDemandStreamURL
                == "https://ondemand/64.mp4")
    }

    /// The programme on air carries the live stream. That is not a recording of it.
    @Test func theLiveStreamIsNeverTheRecording() {
        #expect(episode(startingMinutesFromNow: -10, assets: Self.liveAssets).onDemandStreamURL == nil)
    }

    @Test func nothingWhenDROffersNoRecording() {
        #expect(episode(startingMinutesFromNow: -120, onDemand: false).onDemandStreamURL == nil)
        #expect(episode(startingMinutesFromNow: -120, assets: []).onDemandStreamURL == nil)
        #expect(episode(startingMinutesFromNow: -120, assets: nil).onDemandStreamURL == nil)
    }

    // MARK: - What can be caught up on

    @Test func aFinishedRecordedProgrammeIsCatchUp() {
        #expect(episode(startingMinutesFromNow: -120).isCatchUp(at: now))
    }

    @Test func oneThatEndsNowIsCatchUp() {
        #expect(episode(startingMinutesFromNow: -60).isCatchUp(at: now))
    }

    @Test func theProgrammeOnAirIsNot() {
        #expect(!episode(startingMinutesFromNow: -10).isCatchUp(at: now))
    }

    /// DR has the file for tonight's repeat already; it is still not catch-up.
    @Test func anUpcomingRepeatIsNot() {
        #expect(!episode(startingMinutesFromNow: 120).isCatchUp(at: now))
    }

    @Test func aFinishedProgrammeWithoutARecordingIsNot() {
        #expect(!episode(startingMinutesFromNow: -120, assets: []).isCatchUp(at: now))
    }

    // MARK: - The schedule sheet's day

    /// In the small hours the snapshot reaches back into the previous broadcast day, which
    /// the day schedule does not include; both are kept, once each, in time order.
    @Test func theDayAndTheSnapshotAreMergedOnceEachInOrder() {
        let yesterday = episode(startingMinutesFromNow: -180, id: "urn:yesterday")
        let earlier = episode(startingMinutesFromNow: -120, id: "urn:earlier")
        let onAir = episode(startingMinutesFromNow: -10, id: "urn:onair")
        let later = episode(startingMinutesFromNow: 50, id: "urn:later")

        let merged = DRScheduleResponse.mergedDay([earlier, onAir, later],
                                                  snapshot: [yesterday, onAir, later])

        #expect(merged.map(\.id) == ["urn:yesterday", "urn:earlier", "urn:onair", "urn:later"])
    }

    /// The same episode aired twice is two broadcasts, and stays two rows.
    @Test func aRepeatIsNotMergedAway() {
        let morning = episode(startingMinutesFromNow: -180, id: "urn:same")
        let evening = episode(startingMinutesFromNow: 180, id: "urn:same")

        #expect(DRScheduleResponse.mergedDay([morning, evening], snapshot: []).count == 2)
    }

    /// The shape `/schedules/{slug}/{date}` answers with: more fields than the app reads,
    /// and a file size on each recorded asset.
    @Test func aDayScheduleFromDRDecodes() throws {
        let json = """
            {"type": "Schedule", "id": "urn:dr:radio:schedule:1", "title": "5. okt.",
             "scheduleDate": "2026-10-05",
             "next": "https://api.dr.dk/radio/v5/schedules/p1/2026-10-06",
             "previous": "https://api.dr.dk/radio/v5/schedules/p1/2026-10-04",
             "channel": {"title": "P1", "id": "urn:p1", "slug": "p1", "type": "Channel",
                         "presentationUrl": "https://www.dr.dk/lyd/p1"},
             "items": [{"type": "Episode", "learnId": "l", "durationMilliseconds": 3720000,
                        "categories": [], "productionNumber": "1",
                        "startTime": "2026-10-05T03:03:00+00:00",
                        "endTime": "2026-10-05T04:05:00+00:00", "presentationUrl": null,
                        "order": 1, "nextId": null, "previousId": null, "series": null,
                        "channel": {"title": "P1", "id": "urn:p1", "slug": "p1",
                                    "type": "Channel", "presentationUrl": null},
                        "audioAssets": [{"type": "Audio", "target": "Stream",
                                         "isStreamLive": false, "format": "HLS",
                                         "bitrate": 0, "url": "https://ondemand/hls"},
                                        {"type": "Audio", "target": "Progressive",
                                         "isStreamLive": false, "format": "mp3",
                                         "bitrate": 64, "fileSize": 26546756,
                                         "url": "https://ondemand/64.mp3"}],
                        "isAvailableOnDemand": true, "hasVideo": false,
                        "explicitContent": false, "hasTranscription": false,
                        "id": "urn:dr:radio:episode:1", "slug": "e", "title": "Kampen",
                        "description": "d", "imageAssets": []}]}
            """
        let day = try JSONDecoder().decode(DRScheduleResponse.self, from: Data(json.utf8))

        #expect(day.scheduleDate == "2026-10-05")
        #expect(day.items.first?.onDemandStreamURL == "https://ondemand/hls")
        #expect(day.items.first?.isCatchUp(at: now) == true)
    }

    // MARK: - Leaving a recording

    /// Choosing the station while catching up on one of its programmes means the station,
    /// live — not "leave it alone" because the channel ids match.
    @Test func choosingTheStationLeavesItsRecording() {
        #expect(DRServiceManager.selectionAction(for: p1, loaded: p1, hasLoadedItem: true,
                                                 isPlaying: true, loadedIsOnDemand: true)
                == .restart)
        #expect(DRServiceManager.selectionAction(for: p1, loaded: p1, hasLoadedItem: true,
                                                 isPlaying: false, loadedIsOnDemand: true)
                == .restart)
    }

    // MARK: - Position

    @Test func positionsAreWrittenAsAClockWould() {
        #expect(PlaybackTime.format(0) == "0:00")
        #expect(PlaybackTime.format(65.9) == "1:05")
        #expect(PlaybackTime.format(3_725) == "1:02:05")
    }
}
