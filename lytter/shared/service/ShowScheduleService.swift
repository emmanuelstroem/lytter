//
//  ShowScheduleService.swift
//  lytter
//

import Foundation
import os
import Combine

/// Keeps what the app knows about when favourite shows are on (F33): today's real schedule
/// for the channels it has fetched, and the weekly template in `ScheduleTemplateStore`.
///
/// Each broadcast day, every channel's schedule is fetched once and folded into the
/// template — all of them, so that a show favourited on any channel already has its weeks
/// behind it. On a constrained network (Low Data Mode) only the channels favourite shows
/// have been seen on are fetched. A refresh is due from 05:05 Copenhagen time, when DR's new
/// day is there; the app checks at launch, on returning to the foreground, and from a
/// background refresh that the system runs at or after 05:05.
///
/// An `ObservableObject` of its own, observed directly by the shelves: through
/// `DRServiceManager` it would not redraw them (see AGENTS.md).
final class ShowScheduleService: ObservableObject {

    /// Today's real schedules by channel slug, for the channels fetched this broadcast day.
    @Published private(set) var today: [String: [DREpisode]] = [:]
    /// Bumped each time the template changes, so that views asking `airing(for:)` redraw.
    @Published private(set) var templateRevision = 0

    private var todayFetchedAt: [String: Date] = [:]
    private let store: ScheduleTemplateStore
    private var refreshTask: Task<Void, Never>?

    /// Between channel fetches: the refresh is spread out rather than sent all at once.
    static let foregroundSpacing: Duration = .milliseconds(800)
    /// In the background the system allows about thirty seconds, so it is spread less.
    static let backgroundSpacing: Duration = .milliseconds(150)

    init(store: ScheduleTemplateStore = .shared) {
        self.store = store
    }

    var isRefreshing: Bool { refreshTask != nil }

    /// When `show` is next on, from what is known now.
    func airing(for show: FavouriteShow, now: Date = Date()) -> ShowAiring {
        ShowAiring.next(for: show.seriesID, today: currentToday(now: now),
                        slots: store.slots(forSeries: [show.seriesID]),
                        channelSlugs: show.channelSlugs, now: now)
    }

    /// The reminders to schedule for `shows` at `now` (F51), from the same airings and
    /// template the shelf reads.
    func reminderPlan(for shows: FavouriteShows, now: Date = Date()) -> [PlannedReminder] {
        guard !shows.isEmpty else { return [] }
        return ShowReminderPlanner.plan(shows: shows.shows, today: currentToday(now: now),
                                        slots: store.slots(forSeries: shows.seriesIDs),
                                        now: now)
    }

    /// Today's schedules that are still today's: a schedule fetched before this morning's
    /// 05:05 belongs to a broadcast day that has ended.
    private func currentToday(now: Date) -> [String: [DREpisode]] {
        today.filter { BroadcastClock.isCurrent(fetchedAt: todayFetchedAt[$0.key], now: now) }
    }

    /// The channels to fetch at `now`, those with favourite shows first.
    ///
    /// A channel is due when the template has not had today's schedule for it, or when the
    /// shelf needs today's airings and has none in memory — after a relaunch, the template
    /// has today but the airings went with the process.
    static func channelsDue(_ channels: [DRChannel], favouriteSlugs: Set<String>,
                            constrained: Bool, now: Date,
                            templateFetchedAt: (String) -> Date?,
                            todayFetchedAt: (String) -> Date?) -> [DRChannel] {
        let due = channels.filter { channel in
            let isFavourite = favouriteSlugs.contains(channel.slug)
            if constrained && !isFavourite { return false }
            let learnt = BroadcastClock.isCurrent(fetchedAt: templateFetchedAt(channel.slug),
                                                  now: now)
            let shown = !isFavourite
                || BroadcastClock.isCurrent(fetchedAt: todayFetchedAt(channel.slug), now: now)
            return !learnt || !shown
        }
        return due.filter { favouriteSlugs.contains($0.slug) }
            + due.filter { !favouriteSlugs.contains($0.slug) }
    }

    /// Fetches what is due and folds it in. Does nothing while a refresh is already running.
    ///
    /// - Parameters:
    ///   - fetchDay: one channel's broadcast day, as the schedule sheets fetch it.
    ///   - onDay: called with each day fetched, so favourite shows can be brought up to date.
    func refreshIfDue(channels: [DRChannel], favourites: FavouriteShows, constrained: Bool,
                      inBackground: Bool = false,
                      fetchDay: @escaping (DRChannel) async throws -> [DREpisode],
                      onDay: @escaping ([DREpisode]) -> Void = { _ in }) -> Task<Void, Never>? {
        if let refreshTask { return refreshTask }
        let due = Self.channelsDue(channels, favouriteSlugs: favourites.channelSlugs,
                                   constrained: constrained, now: Date(),
                                   templateFetchedAt: { self.store.fetchedAt(channelSlug: $0) },
                                   todayFetchedAt: { self.todayFetchedAt[$0] })
        guard !due.isEmpty else { return nil }
        Log.network.info("refreshing the show schedule for \(due.count, privacy: .public) channels")

        let spacing = inBackground ? Self.backgroundSpacing : Self.foregroundSpacing
        let task = Task { [weak self] in
            for (index, channel) in due.enumerated() {
                if Task.isCancelled { break }
                if index > 0 { try? await Task.sleep(for: spacing) }
                guard let day = try? await fetchDay(channel), let self else { continue }
                self.record(day, for: channel, at: Date())
                onDay(day)
            }
            self?.refreshTask = nil
        }
        refreshTask = task
        return task
    }

    func cancelRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func record(_ day: [DREpisode], for channel: DRChannel, at date: Date) {
        store.fold(day, channelSlug: channel.slug, fetchedAt: date)
        today[channel.slug] = day.filter { $0.channel.slug == channel.slug }
        todayFetchedAt[channel.slug] = date
        templateRevision += 1
    }
}
