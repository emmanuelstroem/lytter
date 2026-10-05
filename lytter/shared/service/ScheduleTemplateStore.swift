//
//  ScheduleTemplateStore.swift
//  lytter
//

import Foundation
import os
import SwiftData

/// One row of the weekly template: a series seen in a slot, and when. See `TemplateSlot`.
@Model
final class StoredTemplateSlot {
    /// `TemplateSlot.key`: channel, weekday, start minute and series. Unique, so a slot is
    /// updated where it is rather than added again each week.
    @Attribute(.unique) var key: String
    var channelSlug: String
    var weekday: Int
    var startMinute: Int
    var seriesID: String
    var title: String
    var imageURL: String?
    var durationSeconds: Int
    var seenDates: [String]

    init(_ slot: TemplateSlot) {
        key = slot.key
        channelSlug = slot.channelSlug
        weekday = slot.weekday
        startMinute = slot.startMinute
        seriesID = slot.seriesID
        title = slot.title
        imageURL = slot.imageURL
        durationSeconds = slot.durationSeconds
        seenDates = slot.seenDates
    }

    var value: TemplateSlot {
        TemplateSlot(channelSlug: channelSlug, weekday: weekday, startMinute: startMinute,
                     seriesID: seriesID, title: title, imageURL: imageURL,
                     durationSeconds: durationSeconds, seenDates: seenDates)
    }

    func update(from slot: TemplateSlot) {
        if title != slot.title { title = slot.title }
        if imageURL != slot.imageURL { imageURL = slot.imageURL }
        if durationSeconds != slot.durationSeconds { durationSeconds = slot.durationSeconds }
        if seenDates != slot.seenDates { seenDates = slot.seenDates }
    }
}

/// When a channel's day schedule was last folded into the template, so that each channel is
/// fetched once per broadcast day however often the app is opened.
@Model
final class StoredChannelFetch {
    @Attribute(.unique) var channelSlug: String
    var fetchedAt: Date

    init(channelSlug: String, fetchedAt: Date) {
        self.channelSlug = channelSlug
        self.fetchedAt = fetchedAt
    }
}

/// The weekly template, kept in a SwiftData store on the device and updated there (F33).
///
/// The template is learnt, not downloaded: nothing outside the app can correct what a phone
/// or an Apple TV has stored, so the app keeps it current itself by folding in each day's
/// schedule as it fetches it. Rows are updated in place — a sighting added, a title changed,
/// an aged-out slot deleted — rather than the whole template rewritten.
///
/// It can always be thrown away. Losing it costs a week or two of predictions while it
/// relearns, never anything the listener chose; favourite shows live in preferences. So a
/// store that will not open is deleted and started again, and on tvOS, where only caches
/// may be written, the system purging it costs the same.
final class ScheduleTemplateStore {
    static let shared = ScheduleTemplateStore()

    private let container: ModelContainer?
    private var context: ModelContext? { container?.mainContext }

    static let fileName = "ScheduleTemplate.store"

    private convenience init() {
        #if DEBUG
        // UI tests learn from their fixtures alone, and never leave anything behind.
        if UITestFixtures.isActive {
            self.init(url: nil)
            return
        }
        #endif
        self.init(url: Self.defaultURL())
    }

    /// A store at `url`, or held in memory when `url` is nil — as tests use it.
    init(url: URL?) {
        container = Self.openContainer(at: url)
    }

    // MARK: - Reading

    /// Every slot of `seriesIDs`, for working out when those shows are next on.
    func slots(forSeries seriesIDs: Set<String>) -> [TemplateSlot] {
        guard let context, !seriesIDs.isEmpty else { return [] }
        let ids = Array(seriesIDs)
        let descriptor = FetchDescriptor<StoredTemplateSlot>(
            predicate: #Predicate { ids.contains($0.seriesID) })
        return ((try? context.fetch(descriptor)) ?? []).map(\.value)
    }

    /// Every slot on `channelSlug`.
    func slots(onChannel channelSlug: String) -> [TemplateSlot] {
        storedSlots(onChannel: channelSlug).map(\.value)
    }

    /// When `channelSlug`'s schedule was last folded in, if ever.
    func fetchedAt(channelSlug: String) -> Date? {
        storedFetch(channelSlug)?.fetchedAt
    }

    // MARK: - Updating

    /// Folds `day`, one channel's real schedule, into the template and records the fetch.
    /// Existing rows are updated where they are; new ones are inserted and aged-out ones
    /// deleted. Saved before it returns.
    func fold(_ day: [DREpisode], channelSlug: String, fetchedAt: Date) {
        guard let context else { return }
        let stored = storedSlots(onChannel: channelSlug)
        let folded = WeeklyTemplate.fold(day.filter { $0.channel.slug == channelSlug },
                                         into: stored.map(\.value), now: fetchedAt)
        let foldedByKey = Dictionary(folded.map { ($0.key, $0) },
                                     uniquingKeysWith: { first, _ in first })

        for row in stored {
            if let slot = foldedByKey[row.key] {
                row.update(from: slot)
            } else {
                context.delete(row)
            }
        }
        let existing = Set(stored.map(\.key))
        for slot in folded where !existing.contains(slot.key) {
            context.insert(StoredTemplateSlot(slot))
        }

        if let fetch = storedFetch(channelSlug) {
            fetch.fetchedAt = fetchedAt
        } else {
            context.insert(StoredChannelFetch(channelSlug: channelSlug, fetchedAt: fetchedAt))
        }

        do {
            try context.save()
        } catch {
            Log.network.error(
                "could not save the schedule template: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Private

    private func storedSlots(onChannel channelSlug: String) -> [StoredTemplateSlot] {
        guard let context else { return [] }
        let descriptor = FetchDescriptor<StoredTemplateSlot>(
            predicate: #Predicate { $0.channelSlug == channelSlug })
        return (try? context.fetch(descriptor)) ?? []
    }

    private func storedFetch(_ channelSlug: String) -> StoredChannelFetch? {
        guard let context else { return nil }
        var descriptor = FetchDescriptor<StoredChannelFetch>(
            predicate: #Predicate { $0.channelSlug == channelSlug })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private static func openContainer(at url: URL?) -> ModelContainer? {
        let schema = Schema([StoredTemplateSlot.self, StoredChannelFetch.self])
        let configuration = url.map { ModelConfiguration(schema: schema, url: $0) }
            ?? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            guard let url else {
                Log.network.error("could not open an in-memory schedule template")
                return nil
            }
            // Relearnable, so a store that will not open is started again rather than
            // leaving favourite shows without predictions for good.
            Log.network.warning(
                "discarding a schedule template that will not open: \(error.localizedDescription, privacy: .public)")
            removeStore(at: url)
            return try? ModelContainer(for: schema, configurations: configuration)
        }
    }

    /// SQLite keeps a journal and a shared-memory file beside the store.
    private static func removeStore(at url: URL) {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }

    /// In the app group on iOS and tvOS, beside the disk cache, so that a widget or the Top
    /// Shelf could read it later. On tvOS only caches may be written there. On the Mac it
    /// stays in the app's own container: a sandboxed Mac app reaching into a group container
    /// it is not provisioned for is asked about by the system, and nothing on the Mac would
    /// read it from there.
    private static func defaultURL() -> URL? {
        let files = FileManager.default
        #if os(tvOS)
        let base = files.containerURL(forSecurityApplicationGroupIdentifier: DRLocalCache.appGroup)?
            .appendingPathComponent("Library/Caches", isDirectory: true)
            ?? files.urls(for: .cachesDirectory, in: .userDomainMask).first
        #elseif os(iOS)
        let base = files.containerURL(forSecurityApplicationGroupIdentifier: DRLocalCache.appGroup)?
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            ?? files.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        #else
        let base = files.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        #endif
        guard let base else { return nil }
        try? files.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent(fileName)
    }
}
