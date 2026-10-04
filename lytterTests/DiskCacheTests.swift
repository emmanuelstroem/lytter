//
//  DiskCacheTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// The disk cache is what an offline launch has to show (F42), so it must neither vanish
/// on an app update nor pass off a week-old snapshot as current (P13).
@MainActor
struct DiskCacheTests {

    private let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("lytter-cache-test-\(UUID().uuidString).json")
    private let saved = Date(timeIntervalSince1970: 1_790_000_000)

    private var cache: DRLocalCache { DRLocalCache(fileURL: url) }

    private func programme(_ id: String, imageAssets: [DRImageAsset]? = nil) -> DREpisode {
        DREpisode(type: "Episode", learnId: id, durationMilliseconds: 0, categories: nil,
                  productionNumber: nil, startTime: "2026-10-02T22:03:00+00:00",
                  endTime: "2026-10-03T00:00:00+00:00", presentationUrl: nil,
                  order: 0, previousId: nil, nextId: nil, series: nil,
                  channel: DRChannel(id: "urn:p1", title: "P1", slug: "p1", type: "Channel",
                                     presentationUrl: nil),
                  audioAssets: nil, isAvailableOnDemand: false, hasVideo: false,
                  explicitContent: false, id: id, slug: id, title: id, description: nil,
                  imageAssets: imageAssets, episodeNumber: nil, seasonNumber: nil)
    }

    @Test func whatIsSavedComesBack() {
        defer { try? FileManager.default.removeItem(at: url) }
        cache.save([programme("a"), programme("b")], at: saved)

        #expect(cache.load(now: saved.addingTimeInterval(60)).map(\.id) == ["a", "b"])
    }

    @Test func nothingSavedIsEmpty() {
        #expect(cache.load().isEmpty)
    }

    /// Every install has a cache in the format from before the version existed: a bare
    /// array. An update must not throw it away.
    @Test func theUnversionedFormatStillLoads() throws {
        defer { try? FileManager.default.removeItem(at: url) }
        try JSONEncoder().encode([programme("old")]).write(to: url)

        #expect(cache.load().map(\.id) == ["old"])
    }

    @Test func aSnapshotFromAnotherSchemaVersionIsDiscarded() throws {
        defer { try? FileManager.default.removeItem(at: url) }
        let other = DRLocalCache.Snapshot(version: DRLocalCache.schemaVersion + 1,
                                          savedAt: saved, schedules: [programme("a")])
        try JSONEncoder().encode(other).write(to: url)

        #expect(cache.load(now: saved).isEmpty)
    }

    @Test func aSnapshotPastItsMaximumAgeIsDiscarded() {
        defer { try? FileManager.default.removeItem(at: url) }
        cache.save([programme("a")], at: saved)

        #expect(!cache.load(now: saved.addingTimeInterval(DRLocalCache.maxAge - 60)).isEmpty)
        #expect(cache.load(now: saved.addingTimeInterval(DRLocalCache.maxAge + 60)).isEmpty)
    }

    @Test func anUnreadableFileIsEmptyNotACrash() throws {
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not json".utf8).write(to: url)

        #expect(cache.load().isEmpty)
    }

    // MARK: The Top Shelf extension reads this file (P14)

    /// What `TopShelfSharedCache` in the extension decodes, copied here because the test
    /// target cannot see that target's types. If the cache's format changes under it, the
    /// shelf silently falls back to fetching, so the shape is pinned here instead.
    private struct TopShelfView: Decodable {
        struct Item: Decodable {
            struct Channel: Decodable { let id, title, slug, type: String }
            struct Image: Decodable { let id, target, ratio, format: String }
            let channel: Channel
            let title: String?
            let imageAssets: [Image]?
        }
        let version: Int
        let savedAt: Date
        let schedules: [Item]
    }

    @Test func theTopShelfExtensionCanReadWhatIsSaved() throws {
        defer { try? FileManager.default.removeItem(at: url) }
        let art = DRImageAsset(id: "urn:dr:asset:1", target: "SquareImage", ratio: "1:1",
                               format: "image/jpeg", blurHash: nil)
        cache.save([programme("a", imageAssets: [art])], at: saved)

        // The extension's decoder is a plain JSONDecoder, as the cache's encoder is plain.
        let view = try JSONDecoder().decode(TopShelfView.self, from: Data(contentsOf: url))

        #expect(view.version == 1)
        #expect(view.savedAt == saved)
        #expect(view.schedules.map(\.channel.slug) == ["p1"])
        #expect(view.schedules.first?.title == "a")
        #expect(view.schedules.first?.imageAssets?.map(\.id) == ["urn:dr:asset:1"])
    }

    /// The extension duplicates these; a change here without one there breaks the shelf.
    @Test func whatTheExtensionDuplicatesIsUnchanged() {
        #expect(DRLocalCache.appGroup == "group.com.eopio.lytter")
        #expect(DRLocalCache.fileName == "dr_schedules_cache.json")
        #expect(DRLocalCache.schemaVersion == 1)
        #expect(DRLocalCache.maxAge == 7 * 24 * 60 * 60)
    }
}
