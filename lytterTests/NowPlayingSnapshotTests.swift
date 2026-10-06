//
//  NowPlayingSnapshotTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// What the widgets are told (F18). WidgetKit only draws it; which programme, what the
/// subtitle says and when to move on are decided here.
@MainActor
struct NowPlayingSnapshotTests {
    private typealias Support = ShowTestSupport

    private let morning = Support.airing("morgen", on: "p3", at: "2026-10-06 06:00", minutes: 180)
    private let before = Support.airing("nat", on: "p3", at: "2026-10-06 05:00", minutes: 60)
    private let midday = Support.airing("middag", on: "p3", at: "2026-10-06 09:00", minutes: 60)
    private let afternoon = Support.airing("eftermiddag", on: "p3", at: "2026-10-06 10:00", minutes: 120)

    private var p3: DRChannel { Support.channel("p3") }

    private func snapshot(isPlaying: Bool = true, behind: TimeInterval = 0,
                          at now: String = "2026-10-06 07:00",
                          onDemand: Bool = false) -> NowPlayingSnapshot {
        .make(channel: p3, programme: morning, upcoming: [before, morning, afternoon, midday],
              isPlaying: isPlaying, isOnDemand: onDemand,
              secondsBehindLive: behind, now: Support.cph(now))
    }

    // MARK: - Making one

    @Test func keepsTheHeardProgrammeThenWhatFollowsInOrder() {
        // The schedule snapshot starts with the programme before the one on air.
        let titles = snapshot().programmes.map(\.title)
        #expect(titles == ["Show morgen", "Show middag", "Show eftermiddag"])
    }

    @Test func handsOverNoMoreThanTheLimit() {
        let day = (0..<10).map { hour in
            Support.airing("s\(hour)", on: "p3", at: "2026-10-06 \(String(format: "%02d", 9 + hour)):00")
        }
        let made = NowPlayingSnapshot.make(channel: p3, programme: morning, upcoming: day,
                                           isPlaying: true, isOnDemand: false,
                                           secondsBehindLive: 0, now: Support.cph("2026-10-06 07:00"))
        #expect(made.programmes.count == NowPlayingSnapshot.programmeLimit)
    }

    @Test func aRecordingIsOneProgrammeWithNoOffset() {
        let made = snapshot(behind: 120, onDemand: true)
        #expect(made.programmes.map(\.title) == ["Show morgen"])
        #expect(made.secondsBehindLive == 0)
        #expect(made.programme(at: Support.cph("2026-10-07 12:00"))?.title == "Show morgen")
    }

    @Test func atABoundaryTheScheduleSaysWhatIsOnWhenTheCatalogueDoesNot() {
        // The catalogue still lists "morgen", which ended at 09:00; it gives no programme.
        let made = NowPlayingSnapshot.make(channel: p3, programme: nil,
                                           upcoming: [before, morning, midday, afternoon],
                                           isPlaying: false, isOnDemand: false,
                                           secondsBehindLive: 0,
                                           now: Support.cph("2026-10-06 09:00"))
        #expect(made.programmes.map(\.title) == ["Show middag", "Show eftermiddag"])
        #expect(made.programme(at: Support.cph("2026-10-06 09:00"))?.title == "Show middag")
    }

    @Test func namesTheChannelWithItsDistrict() {
        let kbh = DRChannel(id: "urn:p4kbh", title: "P4 København", slug: "p4kbh",
                            type: "Channel", presentationUrl: nil)
        let made = NowPlayingSnapshot.make(channel: kbh, programme: nil, upcoming: [],
                                           isPlaying: false, isOnDemand: false,
                                           secondsBehindLive: 0, now: Date())
        #expect(made.broadcaster == "DR")
        #expect(made.channelName == "P4 - København")
        #expect(made.stationName == "P4")
        #expect(made.district == "København")
        #expect(made.programmes.isEmpty)
    }

    // MARK: - What it shows when

    @Test func movesOnToTheNextProgrammeAtItsStart() {
        let made = snapshot()
        #expect(made.programme(at: Support.cph("2026-10-06 08:59"))?.title == "Show morgen")
        #expect(made.programme(at: Support.cph("2026-10-06 09:00"))?.title == "Show middag")
        #expect(made.next(after: Support.cph("2026-10-06 09:00"))?.title == "Show eftermiddag")
    }

    @Test func showsNoProgrammeOnceEveryKnownOneHasEnded() {
        let made = snapshot()
        #expect(made.programme(at: Support.cph("2026-10-06 12:00")) == nil)
        #expect(made.next(after: Support.cph("2026-10-06 12:00")) == nil)
    }

    @Test func behindLiveTheProgrammeChangesThatMuchLater() {
        let made = snapshot(behind: 10 * 60)
        #expect(made.programme(at: Support.cph("2026-10-06 09:05"))?.title == "Show morgen")
        #expect(made.programme(at: Support.cph("2026-10-06 09:10"))?.title == "Show middag")
        #expect(made.changes(after: Support.cph("2026-10-06 07:00")).first
                == Support.cph("2026-10-06 09:10"))
    }

    @Test func pausedItStaysInTheProgrammeWhereItStopped() {
        let made = snapshot(isPlaying: false, at: "2026-10-06 08:58")
        #expect(made.programme(at: Support.cph("2026-10-06 10:30"))?.title == "Show morgen")
        #expect(made.changes(after: Support.cph("2026-10-06 08:58")).isEmpty)
        #expect(made.clockInterval(of: made.programmes[0]) == nil)
    }

    @Test func theSubtitleIsTheProgrammeNeverTheChannelAgain() {
        #expect(snapshot().subtitle(at: Support.cph("2026-10-06 07:00")) == "Show morgen")

        // DR titles some programmes with the channel's name alone: "P2" under "P2".
        let named = Support.airing("p3", on: "p3", at: "2026-10-06 06:00", minutes: 180, title: "P3")
        let made = NowPlayingSnapshot.make(channel: p3, programme: named, upcoming: [],
                                           isPlaying: true, isOnDemand: false,
                                           secondsBehindLive: 0, now: Support.cph("2026-10-06 07:00"))
        #expect(made.subtitle(at: Support.cph("2026-10-06 07:00")) == nil)
        // And none once the programme has ended.
        #expect(snapshot().subtitle(at: Support.cph("2026-10-06 12:00")) == nil)
    }

    @Test func sameSnapshotWrittenLaterSaysTheSame() {
        let first = snapshot(at: "2026-10-06 07:00")
        #expect(first.says(theSameAs: snapshot(at: "2026-10-06 07:01")))
        #expect(!first.says(theSameAs: snapshot(isPlaying: false)))
        #expect(!first.says(theSameAs: nil))
    }

    // MARK: - Favourites

    private func favourites(_ ids: [String], channels: [DRChannel]) -> FavouriteStations {
        let schedule = [morning]
        return .make(favourites: Favourites(channelIDs: ids), channels: channels) { channel in
            schedule.first { $0.channel.id == channel.id }
        }
    }

    @Test func favouritesKeepThePinnedOrderAndDropWhatTheCatalogueLacks() {
        let p1 = Support.channel("p1")
        let made = favourites(["urn:p3", "urn:gone", "urn:p1"], channels: [p1, p3])
        #expect(made.stations.map(\.channelID) == ["urn:p3", "urn:p1"])
        #expect(made.stations.map(\.broadcaster) == ["DR", "DR"])
        #expect(made.stations[0].programme == "Show morgen")
        #expect(made.stations[1].programme == nil)
        #expect(made.stations.map(\.district) == [nil, nil])
    }

    @Test func favouritesStopAtWhatTheLargestWidgetDraws() {
        let channels = (1...10).map { Support.channel("x\($0)") }
        let made = favourites(channels.map(\.id), channels: channels)
        #expect(made.stations.count == FavouriteStations.limit)
    }

    @Test func aFavouritesProgrammeGoesWhenItEnds() {
        let station = favourites(["urn:p3"], channels: [p3]).stations[0]
        #expect(station.subtitle(at: Support.cph("2026-10-06 08:59")) == "Show morgen")
        #expect(station.subtitle(at: Support.cph("2026-10-06 09:00")) == nil)
        #expect(favourites(["urn:p3"], channels: [p3]).changes(after: Support.cph("2026-10-06 07:00"))
                == [Support.cph("2026-10-06 09:00")])
    }

    // MARK: - The store

    @Test func theStoreReadsBackWhatItWrote() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NowPlayingStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = NowPlayingStore(directory: directory)

        #expect(store.load() == nil)
        let made = snapshot()
        store.save(made)
        store.saveArtwork(Data([1, 2, 3]))
        #expect(store.load() == made)
        #expect(store.artworkData() == Data([1, 2, 3]))

        let pinned = favourites(["urn:p3"], channels: [p3])
        store.saveFavourites(pinned)
        #expect(store.loadFavourites() == pinned)

        store.clear()
        #expect(store.load() == nil)
        #expect(store.artworkData() == nil)
    }

    @Test func theStoreIgnoresAnotherVersion() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NowPlayingStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = NowPlayingStore(directory: directory)
        store.save(snapshot())

        let url = directory.appendingPathComponent(NowPlayingStore.snapshotFileName)
        var json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        json["version"] = NowPlayingSnapshot.schemaVersion + 1
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        #expect(store.load() == nil)
    }
}
