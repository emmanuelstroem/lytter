//
//  DRLocalCache.swift
//  lytter
//

import Foundation
import os
#if os(tvOS)
import TVServices
#endif

// MARK: - Local Disk Cache

/// The last catalogue DR returned, on disk, so a launch has something to show before the
/// network answers — or when it never does (F42).
///
/// Two things made it unsafe to lean on (P13). It had no version, so a change to `DREpisode`
/// that the old file could not decode emptied it without a word: the next offline launch
/// showed "You're offline" with nothing behind it, as if nothing had ever been cached. And it
/// had no age, so a snapshot from last week was loaded as readily as one from a minute ago.
///
/// On tvOS it lives in the app group's container, where the Top Shelf extension reads it
/// rather than fetching the schedule itself (P14). That makes its format a contract with
/// `TopShelfSharedCache`, which decodes the parts it needs: `version`, `savedAt`, and each
/// schedule's `channel`, `title` and `imageAssets`.
///
/// Saving is off the main actor (P16). Every successful fetch saves, and the whole snapshot
/// was encoded and written on the main actor from the fetch's completion; now a save waits
/// briefly, gives way to any save that follows it, and encodes and writes at background
/// priority. The models it writes are `nonisolated` so that they can be encoded there.
final class DRLocalCache {
    static let shared = DRLocalCache()

    /// Bump when `DREpisode` changes in a way an older file cannot decode. A file written
    /// under another version is discarded, and says so in the log.
    static let schemaVersion = 1

    /// Older than this, a snapshot is not loaded at all. Its programmes are long over and
    /// DR's line-up may have moved on; the channel list it would give is not worth showing.
    static let maxAge: TimeInterval = 7 * 24 * 60 * 60

    /// What is written: the schedules, and when and under which version they were saved.
    nonisolated struct Snapshot: Codable {
        let version: Int
        let savedAt: Date
        let schedules: [DREpisode]
    }

    /// How long a save waits before writing. Fetches can land in quick succession — the
    /// launch fetch, a retry, the network coming back — and only the last needs writing.
    static let writeDelay: Duration = .seconds(1)

    private let fileURL: URL?
    private let writeDelay: Duration
    private let decoder = JSONDecoder()

    /// The save waiting to be written, which the next save replaces.
    private var pendingWrite: Task<Void, Never>?

    /// Shared with the Top Shelf extension, which declares the same group and file name.
    static let appGroup = AppGroup.identifier
    static let fileName = "dr_schedules_cache.json"

    private convenience init() {
        let ownCaches = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(Self.fileName)
        #if os(tvOS)
        let shared = Self.sharedFileURL()
        if let shared, let ownCaches { Self.move(ownCaches, to: shared) }
        self.init(fileURL: shared ?? ownCaches)
        #else
        self.init(fileURL: ownCaches)
        #endif
    }

    /// For tests, which point it at a file of their own.
    init(fileURL: URL?, writeDelay: Duration = DRLocalCache.writeDelay) {
        self.fileURL = fileURL
        self.writeDelay = writeDelay
    }

    #if os(tvOS)
    /// The group container's `Library/Caches`: on tvOS only caches may be written, and the
    /// system may purge them, which costs no more than a fetch. Nil if the group is not in
    /// the entitlements, and the cache then stays in the app's own caches as before.
    private static func sharedFileURL() -> URL? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            Log.network.warning("app group unavailable; Top Shelf will fetch for itself")
            return nil
        }
        let caches = container.appendingPathComponent("Library/Caches", isDirectory: true)
        try? FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        return caches.appendingPathComponent(fileName)
    }

    /// Brings the file an earlier version saved in the app's own caches across, once, so
    /// the update does not cost the offline launch its cache.
    private static func move(_ legacy: URL, to shared: URL) {
        let files = FileManager.default
        guard files.fileExists(atPath: legacy.path) else { return }
        if files.fileExists(atPath: shared.path) {
            try? files.removeItem(at: legacy)
        } else {
            try? files.moveItem(at: legacy, to: shared)
        }
    }
    #endif

    /// Persist schedules to disk. Call only after a successful API response.
    ///
    /// Returns at once. The write happens after `writeDelay`, at background priority, unless
    /// another save replaces it first; the task returned finishes when it has, which only
    /// tests need to wait for.
    @discardableResult
    func save(_ schedules: [DREpisode], at date: Date = Date()) -> Task<Void, Never> {
        pendingWrite?.cancel()
        let snapshot = Snapshot(version: Self.schemaVersion, savedAt: date, schedules: schedules)
        let url = fileURL
        let delay = writeDelay
        let write = Task.detached(priority: .background) {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            Self.write(snapshot, to: url)
        }
        pendingWrite = write
        return write
    }

    private nonisolated static func write(_ snapshot: Snapshot, to url: URL?) {
        guard let url, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
        #if os(tvOS)
        // The Top Shelf is drawn from this file now, so ask the system to draw it again.
        TVTopShelfContentProvider.topShelfContentDidChange()
        #endif
    }

    /// The cached schedules, or an empty array if there are none worth using.
    func load(now: Date = Date()) -> [DREpisode] {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return [] }
        guard let snapshot = decode(data, writtenAt: modificationDate(of: url)) else {
            Log.network.warning("discarding a disk cache that does not decode as this version")
            return []
        }
        guard snapshot.version == Self.schemaVersion else {
            Log.network.warning(
                "discarding a disk cache from schema version \(snapshot.version, privacy: .public)")
            return []
        }
        guard now.timeIntervalSince(snapshot.savedAt) <= Self.maxAge else {
            Log.network.info("discarding a disk cache older than its maximum age")
            return []
        }
        return snapshot.schedules
    }

    /// The current format, or the bare array written before it had a version. That one is
    /// read as version 1 — the same `DREpisode` — so an update does not throw away the cache
    /// every existing install has, and dated by the file, which is when it was saved.
    private func decode(_ data: Data, writtenAt fileDate: Date?) -> Snapshot? {
        if let snapshot = try? decoder.decode(Snapshot.self, from: data) { return snapshot }
        guard let legacy = try? decoder.decode([DREpisode].self, from: data) else { return nil }
        return Snapshot(version: 1, savedAt: fileDate ?? .distantPast, schedules: legacy)
    }

    private func modificationDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}
