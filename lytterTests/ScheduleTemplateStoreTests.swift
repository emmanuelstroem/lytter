//
//  ScheduleTemplateStoreTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// The weekly template in its SwiftData store (F33): updated in place, one row per slot.
@MainActor
struct ScheduleTemplateStoreTests {
    private let cph = ShowTestSupport.cph
    private let airing = ShowTestSupport.airing

    @Test func foldingAgainUpdatesTheRowRatherThanAddingOne() {
        let store = ScheduleTemplateStore(url: nil)
        store.fold([airing("s", "p1", "2026-09-28 07:05", 55, false, nil)],
                   channelSlug: "p1", fetchedAt: cph("2026-09-28 06:00"))
        store.fold([airing("s", "p1", "2026-10-05 07:05", 55, false, nil)],
                   channelSlug: "p1", fetchedAt: cph("2026-10-05 06:00"))

        let slots = store.slots(onChannel: "p1")
        #expect(slots.count == 1)
        #expect(slots.first?.seenDates == ["2026-09-28", "2026-10-05"])
    }

    @Test func aTitleChangeIsWrittenToTheExistingRow() {
        let store = ScheduleTemplateStore(url: nil)
        store.fold([airing("s", "p1", "2026-09-28 07:05", 55, false, "Old")],
                   channelSlug: "p1", fetchedAt: cph("2026-09-28 06:00"))
        store.fold([airing("s", "p1", "2026-10-05 07:05", 55, false, "New")],
                   channelSlug: "p1", fetchedAt: cph("2026-10-05 06:00"))

        #expect(store.slots(onChannel: "p1").map(\.title) == ["New"])
    }

    @Test func agedOutRowsAreDeleted() {
        let store = ScheduleTemplateStore(url: nil)
        store.fold([airing("old", "p1", "2026-09-07 07:05", 55, false, nil)],
                   channelSlug: "p1", fetchedAt: cph("2026-09-07 06:00"))
        store.fold([airing("new", "p1", "2026-10-05 08:00", 55, false, nil)],
                   channelSlug: "p1", fetchedAt: cph("2026-10-05 06:00"))

        #expect(store.slots(onChannel: "p1").map(\.seriesID) == [ShowTestSupport.seriesID("new")])
    }

    /// A fold for one channel leaves every other channel's rows alone, and ignores
    /// programmes that are not on the channel it was given.
    @Test func aFoldTouchesOnlyItsChannel() {
        let store = ScheduleTemplateStore(url: nil)
        store.fold([airing("a", "p3", "2026-10-05 07:05", 55, false, nil)],
                   channelSlug: "p3", fetchedAt: cph("2026-10-05 06:00"))
        store.fold([airing("b", "p1", "2026-10-05 07:05", 55, false, nil),
                    airing("stray", "p3", "2026-10-05 09:00", 55, false, nil)],
                   channelSlug: "p1", fetchedAt: cph("2026-10-05 06:00"))

        #expect(store.slots(onChannel: "p3").map(\.seriesID) == [ShowTestSupport.seriesID("a")])
        #expect(store.slots(onChannel: "p1").map(\.seriesID) == [ShowTestSupport.seriesID("b")])
    }

    @Test func theFetchIsRecordedPerChannel() {
        let store = ScheduleTemplateStore(url: nil)
        #expect(store.fetchedAt(channelSlug: "p1") == nil)
        store.fold([], channelSlug: "p1", fetchedAt: cph("2026-10-05 06:00"))
        store.fold([], channelSlug: "p1", fetchedAt: cph("2026-10-06 06:00"))

        #expect(store.fetchedAt(channelSlug: "p1") == cph("2026-10-06 06:00"))
        #expect(store.fetchedAt(channelSlug: "p2") == nil)
    }

    @Test func slotsAreFoundBySeriesAcrossChannels() {
        let store = ScheduleTemplateStore(url: nil)
        store.fold([airing("s", "p1", "2026-10-05 07:05", 55, false, nil)],
                   channelSlug: "p1", fetchedAt: cph("2026-10-05 06:00"))
        store.fold([airing("s", "p3", "2026-10-05 22:00", 55, false, nil),
                    airing("t", "p3", "2026-10-05 23:00", 55, false, nil)],
                   channelSlug: "p3", fetchedAt: cph("2026-10-05 06:00"))

        let found = store.slots(forSeries: [ShowTestSupport.seriesID("s")])
        #expect(Set(found.map(\.channelSlug)) == ["p1", "p3"])
    }

    /// It is on disk, not only in memory: a second store at the same file reads it back.
    @Test func theTemplateSurvivesReopening() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("template.store")

        ScheduleTemplateStore(url: url)
            .fold([airing("s", "p1", "2026-10-05 07:05", 55, false, nil)],
                  channelSlug: "p1", fetchedAt: cph("2026-10-05 06:00"))

        let reopened = ScheduleTemplateStore(url: url)
        #expect(reopened.slots(onChannel: "p1").count == 1)
        #expect(reopened.fetchedAt(channelSlug: "p1") == cph("2026-10-05 06:00"))
    }
}

/// Which channels the daily refresh fetches (F33).
@MainActor
struct ShowScheduleRefreshTests {
    private let cph = ShowTestSupport.cph
    private let channels = ["p1", "p2", "p3", "p6"].map { ShowTestSupport.channel($0) }

    private func due(favourites: Set<String> = [], constrained: Bool = false,
                     learnt: [String: Date] = [:], shown: [String: Date] = [:],
                     at now: String = "2026-10-05 12:00") -> [String] {
        ShowScheduleService.channelsDue(channels, favouriteSlugs: favourites,
                                        constrained: constrained, now: cph(now),
                                        templateFetchedAt: { learnt[$0] },
                                        todayFetchedAt: { shown[$0] })
            .map(\.slug)
    }

    @Test func everyChannelIsDueOnAFreshInstall() {
        #expect(due() == ["p1", "p2", "p3", "p6"])
    }

    @Test func channelsWithFavouriteShowsGoFirst() {
        #expect(due(favourites: ["p3"]) == ["p3", "p1", "p2", "p6"])
    }

    @Test func aConstrainedNetworkFetchesOnlyFavouriteChannels() {
        #expect(due(favourites: ["p3"], constrained: true) == ["p3"])
    }

    @Test func nothingIsDueOnceTodayIsFetched() {
        let morning = cph("2026-10-05 06:00")
        let learnt = Dictionary(uniqueKeysWithValues: channels.map { ($0.slug, morning) })
        #expect(due(favourites: ["p1"], learnt: learnt, shown: ["p1": morning]).isEmpty)
    }

    /// After a relaunch the template has today, but the shelf's airings went with the
    /// process: channels with favourite shows are fetched again, and only those.
    @Test func afterARelaunchOnlyFavouriteChannelsAreFetchedAgain() {
        let morning = cph("2026-10-05 06:00")
        let learnt = Dictionary(uniqueKeysWithValues: channels.map { ($0.slug, morning) })
        #expect(due(favourites: ["p2"], learnt: learnt) == ["p2"])
    }

    @Test func yesterdaysFetchIsDueAgainAfterFiveOFive() {
        let yesterday = cph("2026-10-04 12:00")
        let learnt = Dictionary(uniqueKeysWithValues: channels.map { ($0.slug, yesterday) })
        #expect(due(learnt: learnt, at: "2026-10-05 05:00").isEmpty)
        #expect(due(learnt: learnt, at: "2026-10-05 05:06").count == 4)
    }
}
