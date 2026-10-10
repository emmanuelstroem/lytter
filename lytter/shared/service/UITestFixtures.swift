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

    // MARK: - Network conditions (F42)

    /// A network condition to simulate, from `LYTTER_UITEST_NETWORK`, so the connection
    /// states can be driven in a UI test without touching the machine's own network.
    enum SimulatedNetwork: String {
        /// No route to the internet, and nothing cached: the full-screen offline state.
        case offline
        /// No route, with the fixtures standing in for the disk cache: the banner over them.
        case offlineCached = "offline-cached"
        /// Online, but DR's API answers 503.
        case drDown = "dr-down"
        /// As `drDown`, over cached channels.
        case drDownCached = "dr-down-cached"
        /// Offline at launch, back online a few seconds later — automatic recovery.
        case reconnects
    }

    static var simulatedNetwork: SimulatedNetwork? {
        guard isActive else { return nil }
        return ProcessInfo.processInfo.environment["LYTTER_UITEST_NETWORK"]
            .flatMap(SimulatedNetwork.init(rawValue:))
    }

    /// What the simulated path monitor last reported. Fixture requests fail as offline
    /// while it is false, as real ones would.
    static var isSimulatedOnline = true

    /// Whether the fixtures stand in for the disk cache at launch.
    static var seedsCache: Bool {
        simulatedNetwork == .offlineCached || simulatedNetwork == .drDownCached
    }

    /// The fixture catalogue as `/schedules/all/now` would answer under the simulated
    /// condition.
    static func schedulesResponse() throws -> [DREpisode] {
        if !isSimulatedOnline { throw URLError(.notConnectedToInternet) }
        switch simulatedNetwork {
        case .drDown, .drDownCached: throw NetworkError.httpError(503)
        default: return schedules()
        }
    }

    /// Drives `NetworkMonitor` under UI tests: online unless the condition says otherwise,
    /// whatever the machine running the tests is connected to.
    static func simulatePath(_ onChange: @escaping @MainActor (Bool) -> Void) {
        let report: @MainActor (Bool) -> Void = { online in
            isSimulatedOnline = online
            onChange(online)
        }
        switch simulatedNetwork {
        case .offline, .offlineCached:
            report(false)
        case .reconnects:
            report(false)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(4))
                report(true)
            }
        default:
            report(true)
        }
    }

    /// Every channel DR broadcasts, each with a programme on air now whose description is
    /// far longer than the player's info sheet can show at once.
    static func schedules(now: Date = Date()) -> [DREpisode] {
        channels.map { channel in
            episode(on: channel,
                    index: 0,
                    start: now.addingTimeInterval(-30 * 60),
                    end: now.addingTimeInterval(30 * 60),
                    title: hasLongTitles
                        ? "\(channel.name) \(longProgrammeTitle)"
                        : "\(channel.name) Fixture: Et langt program",
                    description: longDescription)
        }
    }

    // MARK: - Long titles

    /// Whether the programmes on air carry titles wider than any phone, with a track on air
    /// whose artist and title are as long, from `LYTTER_UITEST_LONG_TITLES`. Off unless asked
    /// for, so every other test sees the short titles it was written against.
    static var hasLongTitles: Bool {
        isActive && ProcessInfo.processInfo.environment["LYTTER_UITEST_LONG_TITLES"] == "1"
    }

    static let longProgrammeTitle =
        "Morgenhyrderne med Søren og Mette direkte fra Aarhus hele formiddagen"
    static let longTrackArtist = "Christopher Rasmussen & The Copenhagen Philharmonic"
    static let longTrackTitle = "A Very Long Song Title That Keeps Going (Extended Radio Edit)"

    /// What `/indexpoints/live` would answer for a channel: one track, on air now, when the
    /// long titles are asked for.
    static func indexPoints(for slug: String, now: Date = Date()) throws -> DRIndexPointsResponse {
        guard hasLongTitles, let channel = channels.first(where: { $0.slug == slug }) else {
            throw NetworkError.invalidResponse
        }
        let track = DRTrack(type: "Music", durationMilliseconds: 60 * 60 * 1000,
                            playedTime: formatter.string(from: now.addingTimeInterval(-60)),
                            musicUrl: "", trackUrn: "urn:fixture:track:\(slug)",
                            classical: false,
                            roles: [DRTrackRole(artistUrn: "urn:fixture:artist",
                                                role: "Hovedkunstner", name: longTrackArtist,
                                                musicUrl: "")],
                            title: longTrackTitle, description: longTrackArtist)
        return DRIndexPointsResponse(type: "IndexPoints", channel: channel, totalSize: 1,
                                     items: [track], id: "urn:fixture:indexpoints:\(slug)")
    }

    /// Today's schedule for one channel: more programmes than the schedule sheet shows at
    /// once, with the one on air in the middle. Every other finished programme has a
    /// recording, so the sheet carries both kinds of row (F16).
    static func schedule(for slug: String, now: Date = Date()) -> DRScheduleResponse? {
        guard let channel = channels.first(where: { $0.slug == slug }) else { return nil }
        let items = (0..<30).map { index -> DREpisode in
            let start = now.addingTimeInterval(TimeInterval((index - 15) * 30 * 60))
            return episode(on: channel,
                           index: index,
                           start: start,
                           end: start.addingTimeInterval(30 * 60),
                           title: "Fixture-program \(index + 1)",
                           description: "Beskrivelse af program \(index + 1).",
                           recorded: index < 15 && index.isMultiple(of: 2),
                           series: index % seriesCount)
        }
        return DRScheduleResponse(type: "Schedule", channel: channel, items: items,
                                  scheduleDate: nil)
    }

    // MARK: - A second broadcaster (F54)

    /// Whether `FixtureSource` is registered beside DR, from `LYTTER_UITEST_SECOND_BROADCASTER`.
    /// Off unless asked for, so every other test sees DR alone, as a listener does today.
    static var hasSecondBroadcaster: Bool {
        isActive && ProcessInfo.processInfo.environment["LYTTER_UITEST_SECOND_BROADCASTER"] == "1"
    }

    /// The second broadcaster's catalogue: offline when the simulated network is, and up
    /// when only DR is down.
    static func secondBroadcasterResponse(now: Date = Date()) throws -> [DREpisode] {
        if !isSimulatedOnline { throw URLError(.notConnectedToInternet) }
        return secondBroadcasterChannels.map { channel in
            episode(on: channel,
                    index: 0,
                    start: now.addingTimeInterval(-30 * 60),
                    end: now.addingTimeInterval(30 * 60),
                    title: "\(channel.name) Fixture: Morgen",
                    description: "Et program på en anden radiostation.")
        }
    }

    /// Named as a directory would name them, so "Testradio Pop" is a station of its own
    /// rather than a district "Pop" of a station "Testradio". Ids in the broadcaster's own
    /// namespace, as `BroadcasterSource` requires.
    private static var secondBroadcasterChannels: [DRChannel] {
        ["Pop", "Rock", "Jazz"].map { genre in
            let slug = "testradio-\(genre.lowercased())"
            return DRChannel(id: "urn:lytter:fixture:\(slug)", title: "Testradio \(genre)",
                             slug: slug, type: "Channel", presentationUrl: nil,
                             stationSlug: slug, stationTitle: "Testradio \(genre)",
                             broadcasterID: FixtureSource.broadcaster.id)
        }
    }

    // MARK: - Favourite shows (F33)

    /// How many series the schedule fixture rotates through: each airs three times a day.
    static let seriesCount = 10

    /// Favourite shows to start with, from `LYTTER_UITEST_FAVOURITE_SHOWS` (a count), in
    /// place of whatever the simulator has stored — none, when it is not set. Nil outside
    /// UI tests.
    static var favouriteShows: [FavouriteShow]? {
        guard isActive else { return nil }
        let count = ProcessInfo.processInfo.environment["LYTTER_UITEST_FAVOURITE_SHOWS"]
            .flatMap(Int.init) ?? 0
        return (0..<min(count, seriesCount)).map { index in
            FavouriteShow(seriesID: seriesID(index), title: seriesTitle(index), imageURL: nil,
                          channelSlugs: ["p1"])
        }
    }

    private static func seriesID(_ index: Int) -> String { "urn:fixture:series:\(index)" }
    private static func seriesTitle(_ index: Int) -> String { "Fixture-serie \(index + 1)" }

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
                                title: String, description: String,
                                recorded: Bool = false, series: Int? = nil) -> DREpisode {
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
            series: series.map { index in
                DRSeries(id: seriesID(index), title: seriesTitle(index),
                         slug: "fixture-serie-\(index + 1)", type: "Series",
                         isAvailableOnDemand: true, presentationUrl: nil, learnId: "")
            },
            channel: channel,
            // Nothing listens on this address, so playback fails at once and quietly —
            // what the tests need is the player on screen, not audio.
            audioAssets: recorded
                ? [DRAudioAsset(type: "Audio", target: "Stream", isStreamLive: false,
                                format: "HLS", bitrate: nil,
                                url: "http://127.0.0.1:9/fixture-recording.m3u8")]
                : [DRAudioAsset(type: "Audio", target: "Stream", isStreamLive: true,
                                format: "HLS", bitrate: nil,
                                url: "http://127.0.0.1:9/fixture.m3u8")],
            isAvailableOnDemand: recorded,
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
