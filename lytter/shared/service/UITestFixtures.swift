//
//  UITestFixtures.swift
//  lytter
//

import Foundation

#if DEBUG
/// Fixed data for UI tests, in place of DR's live API.
///
/// On tvOS a list scrolls only if something in it can take focus, and nothing warns when
/// that is not so: a sheet of text simply sits there, unscrollable, until someone finds it
/// with a remote. The UI tests in `TVScrollingUITests` drive every scrolling surface with
/// remote presses, and to be worth anything they need content that is always long enough
/// to scroll. Live data is not — a programme description is sometimes two lines, and the
/// schedule shrinks through the day.
///
/// Switched on by the `LYTTER_UITEST_FIXTURES` environment variable, which only the UI
/// tests set, and compiled into debug builds only. Built from the app's own model types
/// rather than JSON, so a model change that breaks the fixtures breaks the build.
enum UITestFixtures {

    static var isActive: Bool {
        ProcessInfo.processInfo.environment["LYTTER_UITEST_FIXTURES"] == "1"
    }

    /// Every channel DR broadcasts, each with a programme on air now whose description is
    /// far longer than the player's info sheet can show at once.
    static func schedules(now: Date = Date()) -> [DREpisode] {
        channels.map { channel in
            episode(on: channel,
                    index: 0,
                    start: now.addingTimeInterval(-30 * 60),
                    end: now.addingTimeInterval(30 * 60),
                    title: "\(channel.name) Fixture: Et langt program",
                    description: longDescription)
        }
    }

    /// Today's schedule for one channel: more programmes than the schedule sheet shows at
    /// once, with the one on air in the middle.
    static func schedule(for slug: String, now: Date = Date()) -> DRScheduleResponse? {
        guard let channel = channels.first(where: { $0.slug == slug }) else { return nil }
        let items = (0..<30).map { index -> DREpisode in
            let start = now.addingTimeInterval(TimeInterval((index - 15) * 30 * 60))
            return episode(on: channel,
                           index: index,
                           start: start,
                           end: start.addingTimeInterval(30 * 60),
                           title: "Fixture-program \(index + 1)",
                           description: "Beskrivelse af program \(index + 1).")
        }
        return DRScheduleResponse(type: "Schedule", channel: channel, items: items,
                                  scheduleDate: nil)
    }

    // MARK: - Building blocks

    private static let titles = [
        "P1", "P2", "P3",
        "P4 Bornholm", "P4 Esbjerg", "P4 Fyn", "P4 København", "P4 Midt & Vest",
        "P4 Nordjylland", "P4 Sjælland", "P4 Syd", "P4 Trekanten", "P4 Østjylland",
        "P5 Bornholm", "P5 Esbjerg", "P5 Fyn", "P5 København", "P5 Midt & Vest",
        "P5 Nordjylland", "P5 Sjælland", "P5 Syd", "P5 Trekanten", "P5 Østjylland",
        "P6", "P8"
    ]

    private static var channels: [DRChannel] {
        titles.map { title in
            let slug = title.lowercased()
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "&", with: "")
            return DRChannel(id: "urn:fixture:\(slug)", title: title, slug: slug,
                             type: "Channel", presentationUrl: nil)
        }
    }

    /// Several paragraphs, so it overflows the info sheet on any screen.
    private static let longDescription = Array(repeating: """
        Dette er en fast testbeskrivelse, der er længere end det, informationsarket kan \
        vise på én gang. Den findes for at kontrollere, at teksten kan rulles med \
        fjernbetjeningen, både ved at klikke og ved at stryge.
        """, count: 8).joined(separator: "\n\n") + "\n\nSidste linje i beskrivelsen."

    private static let formatter = ISO8601DateFormatter()

    private static func episode(on channel: DRChannel, index: Int, start: Date, end: Date,
                                title: String, description: String) -> DREpisode {
        DREpisode(
            type: "Episode",
            learnId: "",
            durationMilliseconds: Int(end.timeIntervalSince(start) * 1000),
            categories: nil,
            productionNumber: nil,
            startTime: formatter.string(from: start),
            endTime: formatter.string(from: end),
            presentationUrl: nil,
            order: index,
            previousId: nil,
            nextId: nil,
            series: nil,
            channel: channel,
            // Nothing listens on this address, so playback fails at once and quietly —
            // what the tests need is the player on screen, not audio.
            audioAssets: [DRAudioAsset(type: "Audio", target: "Stream", isStreamLive: true,
                                       format: "HLS", bitrate: nil,
                                       url: "http://127.0.0.1:9/fixture.m3u8")],
            isAvailableOnDemand: false,
            hasVideo: nil,
            explicitContent: nil,
            id: "urn:fixture:episode:\(channel.slug):\(index)",
            slug: "fixture-\(channel.slug)-\(index)",
            title: title,
            description: description,
            imageAssets: nil,
            episodeNumber: nil,
            seasonNumber: nil
        )
    }
}
#endif
