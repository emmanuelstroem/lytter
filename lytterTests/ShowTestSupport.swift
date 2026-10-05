//
//  ShowTestSupport.swift
//  lytterTests
//

import Foundation
@testable import lytter

/// Builds the programmes the favourite-show tests fold and look through (F33), on
/// Copenhagen wall-clock times, since that is what the weekly template is kept in.
@MainActor
enum ShowTestSupport {

    static func channel(_ slug: String) -> DRChannel {
        DRChannel(id: "urn:\(slug)", title: slug.uppercased(), slug: slug, type: "Channel",
                  presentationUrl: nil)
    }

    /// "2026-10-05 07:05" in Copenhagen.
    static func cph(_ text: String) -> Date {
        let parts = text.split(whereSeparator: { $0 == "-" || $0 == " " || $0 == ":" })
            .compactMap { Int($0) }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = parts[3]
        components.minute = parts[4]
        return BroadcastClock.calendar.date(from: components)!
    }

    static let recording = [
        DRAudioAsset(type: "Audio", target: "Stream", isStreamLive: false, format: "HLS",
                     bitrate: 0, url: "https://ondemand/hls")
    ]

    /// A programme of `series` on `slug` from `start`, Copenhagen time.
    static func airing(_ series: String?, on slug: String = "p1", at start: String,
                       minutes: Double = 55, recorded: Bool = false,
                       title: String? = nil) -> DREpisode {
        let startDate = cph(start)
        let format = ISO8601DateFormatter()
        let seriesTitle = title ?? series.map { "Show \($0)" }
        return DREpisode(
            type: "Episode", learnId: "", durationMilliseconds: Int(minutes * 60_000),
            categories: nil, productionNumber: nil,
            startTime: format.string(from: startDate),
            endTime: format.string(from: startDate.addingTimeInterval(minutes * 60)),
            presentationUrl: nil, order: 0, previousId: nil, nextId: nil,
            series: series.map {
                DRSeries(id: "urn:dr:radio:series:\($0)", title: seriesTitle ?? $0, slug: $0,
                         type: "Series", isAvailableOnDemand: true, presentationUrl: nil,
                         learnId: "")
            },
            channel: channel(slug), audioAssets: recorded ? recording : nil,
            isAvailableOnDemand: recorded, hasVideo: nil, explicitContent: nil,
            id: "urn:episode:\(series ?? "none"):\(start)", slug: "e", title: seriesTitle ?? "Untitled",
            description: nil, imageAssets: nil, episodeNumber: nil, seasonNumber: nil)
    }

    static func seriesID(_ name: String) -> String { "urn:dr:radio:series:\(name)" }
}
