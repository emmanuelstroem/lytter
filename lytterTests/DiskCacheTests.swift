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

    private func programme(_ id: String) -> DREpisode {
        DREpisode(type: "Episode", learnId: id, durationMilliseconds: 0, categories: nil,
                  productionNumber: nil, startTime: "2026-10-02T22:03:00+00:00",
                  endTime: "2026-10-03T00:00:00+00:00", presentationUrl: nil,
                  order: 0, previousId: nil, nextId: nil, series: nil,
                  channel: DRChannel(id: "urn:p1", title: "P1", slug: "p1", type: "Channel",
                                     presentationUrl: nil),
                  audioAssets: nil, isAvailableOnDemand: false, hasVideo: false,
                  explicitContent: false, id: id, slug: id, title: id, description: nil,
                  imageAssets: nil, episodeNumber: nil, seasonNumber: nil)
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
}
