//
//  ShowReminderTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// Which reminders are scheduled before favourite shows start (F51).
@MainActor
struct ShowReminderPlannerTests {
    private let cph = ShowTestSupport.cph
    private let airing = ShowTestSupport.airing
    private let show = FavouriteShow(seriesID: ShowTestSupport.seriesID("s"), title: "Sorte tal",
                                     imageURL: nil, channelSlugs: ["p1"])

    /// Seen on P1 on Tuesdays at 07:05 for two weeks: predicted from then on.
    private var tuesdaySlots: [TemplateSlot] {
        [[airing("s", "p1", "2026-09-29 07:05", 55, false, nil)],
         [airing("s", "p1", "2026-10-06 07:05", 55, false, nil)]]
            .reduce([]) { WeeklyTemplate.fold($1, into: $0, now: cph("2026-10-06 12:00")) }
    }

    private func plan(today: [String: [DREpisode]] = [:], slots: [TemplateSlot] = [],
                      shows: [FavouriteShow]? = nil, at now: String,
                      limit: Int = ShowReminderPlanner.limit) -> [PlannedReminder] {
        ShowReminderPlanner.plan(shows: shows ?? [show], today: today, slots: slots,
                                 now: cph(now), limit: limit)
    }

    @Test func aRealAiringRingsFiveMinutesBefore() {
        let reminders = plan(today: ["p1": [airing("s", "p1", "2026-10-05 22:03", 55, false, nil)]],
                             at: "2026-10-05 12:00")
        #expect(reminders.count == 1)
        #expect(reminders.first?.fireDate == cph("2026-10-05 21:58"))
        #expect(reminders.first?.isPredicted == false)
        #expect(reminders.first?.showTitle == "Sorte tal")
    }

    @Test func onlyFavouriteShowsRing() {
        let reminders = plan(today: ["p1": [airing("other", "p1", "2026-10-05 22:03", 55, false, nil)]],
                             at: "2026-10-05 12:00")
        #expect(reminders.isEmpty)
    }

    /// One whose moment has passed would ring at once, for a programme already starting.
    @Test func aReminderWhoseTimeHasPassedIsNotScheduled() {
        let today = ["p1": [airing("s", "p1", "2026-10-05 12:03", 55, false, nil)]]
        #expect(plan(today: today, at: "2026-10-05 11:59").isEmpty)
        #expect(plan(today: today, at: "2026-10-05 11:57").count == 1)
    }

    /// A week ahead from the template, so a device opened once a week still rings.
    @Test func predictionsCoverTheComingWeek() {
        let reminders = plan(slots: tuesdaySlots, at: "2026-10-07 12:00")
        #expect(reminders.map(\.start) == [cph("2026-10-13 07:05")])
        #expect(reminders.first?.isPredicted == true)
    }

    @Test func nothingBeyondSevenDays() {
        // Tuesday 07:10: this week's has passed, and next week's is seven days less five
        // minutes away — inside. The one after is not.
        let reminders = plan(slots: tuesdaySlots, at: "2026-10-13 07:10")
        #expect(reminders.map(\.start) == [cph("2026-10-20 07:05")])
    }

    /// The real schedule replaces the guess at the same time: one reminder, not two, and
    /// it no longer says "usually".
    @Test func aRealAiringReplacesThePredictionAtTheSameTime() {
        let today = ["p1": [airing("s", "p1", "2026-10-13 07:05", 55, false, nil)]]
        let reminders = plan(today: today, slots: tuesdaySlots, at: "2026-10-13 06:00")
        let atSeven = reminders.filter { $0.start == cph("2026-10-13 07:05") }
        #expect(atSeven.count == 1)
        #expect(atSeven.first?.isPredicted == false)
    }

    /// Today's real schedule says it moved: the predicted time is dropped, the real one rings.
    @Test func aMovedProgrammeRingsAtItsNewTimeOnly() {
        let today = ["p1": [airing("s", "p1", "2026-10-13 09:00", 55, false, nil)]]
        let reminders = plan(today: today, slots: tuesdaySlots, at: "2026-10-13 06:00")
        let todays = reminders.filter { BroadcastClock.broadcastDayKey($0.start) == "2026-10-13" }
        #expect(todays.map(\.start) == [cph("2026-10-13 09:00")])
    }

    @Test func soonestFirstAndCappedUnderTheSystemLimit() {
        let today = ["p1": (0..<10).map { hour in
            airing("s", "p1", String(format: "2026-10-05 %02d:00", 13 + hour), 55, false, nil)
        }]
        let reminders = plan(today: today, at: "2026-10-05 12:00", limit: 4)
        #expect(reminders.map(\.start) == (13..<17).map { cph(String(format: "2026-10-05 %02d:00", $0)) })
    }

    @Test func identifiersCarryTheirPrefix() {
        let reminders = plan(today: ["p1": [airing("s", "p1", "2026-10-05 22:03", 55, false, nil)]],
                             at: "2026-10-05 12:00")
        #expect(reminders.allSatisfy { $0.identifier.hasPrefix(ShowReminderPlanner.identifierPrefix) })
    }

    @Test func aPredictionSaysSo() {
        let real = plan(today: ["p1": [airing("s", "p1", "2026-10-05 22:03", 55, false, nil)]],
                        at: "2026-10-05 12:00")[0]
        let predicted = plan(slots: tuesdaySlots, at: "2026-10-07 12:00")[0]
        #expect(!real.body(channelTitle: "P1").localizedCaseInsensitiveContains("usually"))
        #expect(predicted.body(channelTitle: "P1").localizedCaseInsensitiveContains("usually"))
    }
}

#if os(iOS) || os(macOS)
/// The replace-all pass, against a notification centre that records what it is asked (F51).
@MainActor
struct ShowReminderSchedulerTests {

    final class FakeCenter: ReminderNotificationCenter {
        var pending: [String]
        var authorized: Bool
        private(set) var removed: [String] = []
        private(set) var scheduled: [String] = []

        init(pending: [String] = [], authorized: Bool = true) {
            self.pending = pending
            self.authorized = authorized
        }

        func pendingIdentifiers() async -> [String] { pending }
        func removePending(withIdentifiers identifiers: [String]) {
            removed += identifiers
            pending.removeAll { identifiers.contains($0) }
        }
        func isAuthorized() async -> Bool { authorized }
        func schedule(_ reminder: PlannedReminder, body: String) async throws {
            scheduled.append(reminder.identifier)
            pending.append(reminder.identifier)
        }
    }

    private func reminder(_ minutes: Double) -> PlannedReminder {
        let start = Date(timeIntervalSince1970: 1_791_194_400 + minutes * 60)
        return PlannedReminder(
            identifier: ShowReminderPlanner.identifier(channelSlug: "p1", start: start),
            fireDate: start.addingTimeInterval(-300), start: start, seriesID: "s",
            showTitle: "Sorte tal", channelSlug: "p1", isPredicted: false)
    }

    private let old = ShowReminderPlanner.identifierPrefix + "p1|1"
    private let other = "something-else"

    @Test func aPassReplacesItsOwnRemindersAndLeavesOthersAlone() async {
        let center = FakeCenter(pending: [old, other])
        await ShowReminderScheduler(center: center)
            .reschedule([reminder(60), reminder(120)], enabled: true) { $0 }

        #expect(center.removed == [old])
        #expect(center.pending.sorted() == ([other] + [reminder(60), reminder(120)].map(\.identifier)).sorted())
    }

    @Test func switchedOffRemovesEveryReminderAndSchedulesNone() async {
        let center = FakeCenter(pending: [old, other])
        await ShowReminderScheduler(center: center).reschedule([reminder(60)], enabled: false) { $0 }

        #expect(center.pending == [other])
        #expect(center.scheduled.isEmpty)
    }

    @Test func withoutPermissionNothingIsScheduled() async {
        let center = FakeCenter(pending: [old], authorized: false)
        await ShowReminderScheduler(center: center).reschedule([reminder(60)], enabled: true) { $0 }

        #expect(center.pending.isEmpty)
        #expect(center.scheduled.isEmpty)
    }

    /// Two passes in a row leave one set, not two.
    @Test func passesDoNotAccumulate() async {
        let center = FakeCenter()
        let scheduler = ShowReminderScheduler(center: center)
        await scheduler.reschedule([reminder(60)], enabled: true) { $0 }
        await scheduler.reschedule([reminder(60)], enabled: true) { $0 }

        #expect(center.pending == [reminder(60).identifier])
    }
}
#endif

#if os(iOS) || os(macOS)
/// A tapped reminder becomes a deep link to its channel (F51), even one tapped before the
/// scene is there to take it.
@MainActor
struct ReminderTapTests {

    @Test func aTapOpensTheChannelsDeepLink() {
        let delegate = ReminderNotificationDelegate()
        var opened: [URL] = []
        delegate.onOpen = { opened.append($0) }

        delegate.openChannel(slug: "p3")

        #expect(opened == [URL(string: "lytter:///channel/p3")!])
    }

    @Test func aTapBeforeTheSceneIsHeldUntilItArrives() {
        let delegate = ReminderNotificationDelegate()
        delegate.openChannel(slug: "p1")

        var opened: [URL] = []
        delegate.onOpen = { opened.append($0) }
        delegate.onOpen = { opened.append($0) }

        #expect(opened == [URL(string: "lytter:///channel/p1")!])
    }

    /// The link resolves the way a Top Shelf link does: by slug.
    @Test func theLinkIsOneTheDeepLinkHandlerAccepts() {
        let handler = DeepLinkHandler()
        handler.handleDeepLink(URL(string: "lytter:///channel/p3")!)
        #expect(handler.pendingChannelId == "p3")
    }
}
#endif
