//
//  TopShelfSharedCache.swift
//  TopShelfExtension
//

import Foundation
import os

#if os(tvOS)
/// The app's schedule cache, read from the app group's container (P14).
///
/// The app writes it after every successful catalogue fetch and then asks the system to
/// redraw the Top Shelf, so most refreshes find a recent snapshot and make no request of
/// their own. The file is `DRLocalCache`'s, which this target cannot see: the group, file
/// name, schema version and maximum age below are duplicated from it, and must match.
struct TopShelfSharedCache {
    static let appGroup = "group.com.eopio.lytter"
    static let fileName = "dr_schedules_cache.json"
    static let schemaVersion = 1
    static let maxAge: TimeInterval = 7 * 24 * 60 * 60

    /// Younger than this, the snapshot is shown without asking DR. The shelf shows each
    /// channel and the artwork of its programme, and programmes run about an hour.
    static let freshFor: TimeInterval = 60 * 60

    /// The parts of `DRLocalCache.Snapshot` the shelf needs. The app's encoder writes
    /// `savedAt` as the default, seconds since the reference date, so this decoder reads it
    /// the same way rather than as ISO 8601.
    struct Snapshot: Decodable {
        let version: Int
        let savedAt: Date
        let schedules: [TopShelfScheduleItem]

        func age(at now: Date) -> TimeInterval { now.timeIntervalSince(savedAt) }
    }

    private let fileURL: URL?

    init(fileURL: URL? = TopShelfSharedCache.sharedFileURL()) {
        self.fileURL = fileURL
    }

    /// The app's snapshot, if there is one of this version and no older than `maxAge`.
    func load(now: Date = Date()) -> Snapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        guard let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            TopShelfLog.provider.warning("shared cache does not decode; ignoring it")
            return nil
        }
        guard snapshot.version == Self.schemaVersion,
              snapshot.age(at: now) <= Self.maxAge,
              !snapshot.schedules.isEmpty else { return nil }
        return snapshot
    }

    private static func sharedFileURL() -> URL? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            TopShelfLog.provider.warning("app group unavailable; fetching for the shelf")
            return nil
        }
        return container.appendingPathComponent("Library/Caches/\(fileName)")
    }
}
#endif
