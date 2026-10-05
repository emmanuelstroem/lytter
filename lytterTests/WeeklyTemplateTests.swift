//
//  WeeklyTemplateTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// DR's clock: Copenhagen time, a day that turns at 05:00, and a refresh due at 05:05.
@MainActor
struct BroadcastClockTests {
    private let cph = ShowTestSupport.cph

    @Test func beforeFiveOFiveTheLatestRefreshWasYesterdays() {
        #expect(BroadcastClock.latestRefresh(atOrBefore: cph("2026-10-05 05:04"))
                == cph("2026-10-04 05:05"))
    }

    @Test func fromFiveOFiveTheLatestRefreshIsTodays() {
        #expect(BroadcastClock.latestRefresh(atOrBefore: cph("2026-10-05 05:05"))
                == cph("2026-10-05 05:05"))
        #expect(BroadcastClock.latestRefresh(atOrBefore: cph("2026-10-05 23:59"))
                == cph("2026-10-05 05:05"))
    }

    @Test func theNextRefreshIsTomorrowsOnceTodaysHasPassed() {
        #expect(BroadcastClock.nextRefresh(after: cph("2026-10-05 06:00")) == cph("2026-10-06 05:05"))
        #expect(BroadcastClock.nextRefresh(after: cph("2026-10-05 04:00")) == cph("2026-10-05 05:05"))
    }

    /// Kept in Copenhagen wall-clock time, so it follows DR across the change to winter
    /// time: 05:05 is 03:05 UTC in summer and 04:05 UTC from 25 October 2026.
    @Test func theRefreshFollowsCopenhagenAcrossTheChangeToWinterTime() {
        let utc = TimeZone(identifier: "UTC")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let summer = BroadcastClock.latestRefresh(atOrBefore: cph("2026-10-24 12:00"))
        let winter = BroadcastClock.latestRefresh(atOrBefore: cph("2026-10-26 12:00"))
        #expect(calendar.component(.hour, from: summer) == 3)
        #expect(calendar.component(.hour, from: winter) == 4)
    }

    @Test func somethingFetchedBeforeThisMorningsRefreshIsStale() {
        let now = cph("2026-10-05 12:00")
        #expect(!BroadcastClock.isCurrent(fetchedAt: cph("2026-10-05 05:00"), now: now))
        #expect(BroadcastClock.isCurrent(fetchedAt: cph("2026-10-05 05:06"), now: now))
        #expect(!BroadcastClock.isCurrent(fetchedAt: nil, now: now))
    }

    /// One in the morning on a Tuesday is still Monday's broadcast day.
    @Test func theSmallHoursBelongToThePreviousBroadcastDay() {
        #expect(BroadcastClock.broadcastDayKey(cph("2026-10-06 01:00")) == "2026-10-05")
        #expect(BroadcastClock.broadcastDayKey(cph("2026-10-06 05:00")) == "2026-10-06")
    }
}

/// Folding real schedules into the weekly template, and what it then predicts (F33).
@MainActor
struct WeeklyTemplateTests {
    private let cph = ShowTestSupport.cph
    private let airing = ShowTestSupport.airing

    private func fold(_ days: [[DREpisode]], now: Date) -> [TemplateSlot] {
        days.reduce([]) { WeeklyTemplate.fold($1, into: $0, now: now) }
    }

    @Test func aSlotIsTheChannelWeekdayAndCopenhagenStartTime() {
        let slots = fold([[airing("sorte-tal", "p1", "2026-10-05 07:05", 55, false, nil)]],
                         now: cph("2026-10-05 12:00"))

        #expect(slots.count == 1)
        #expect(slots.first?.channelSlug == "p1")
        #expect(slots.first?.weekday == 2) // Monday
        #expect(slots.first?.startMinute == 7 * 60 + 5)
        #expect(slots.first?.seenDates == ["2026-10-05"])
    }

    @Test func foldingTheSameDayTwiceCountsItOnce() {
        let day = [airing("s", "p1", "2026-10-05 07:05", 55, false, nil)]
        let slots = fold([day, day], now: cph("2026-10-05 12:00"))
        #expect(slots.first?.seenDates == ["2026-10-05"])
    }

    @Test func programmesWithoutASeriesAreNotLearnt() {
        let slots = fold([[airing(nil, "p1", "2026-10-05 07:00", 55, false, nil)]],
                         now: cph("2026-10-05 12:00"))
        #expect(slots.isEmpty)
    }

    /// The same series twice in a day is two slots: "Sorte tal" airs 07:05 and 22:03.
    @Test func repeatAiringsInADayAreSeparateSlots() {
        let slots = fold([[airing("s", "p1", "2026-10-05 07:05", 55, false, nil),
                           airing("s", "p1", "2026-10-05 22:03", 55, false, nil)]],
                         now: cph("2026-10-05 23:00"))
        #expect(slots.map(\.startMinute).sorted() == [7 * 60 + 5, 22 * 60 + 3])
    }

    @Test func seenOnceIsNotPredicted() {
        let now = cph("2026-10-05 12:00")
        let slots = fold([[airing("s", "p1", "2026-10-05 07:05", 55, false, nil)]], now: now)
        #expect(!WeeklyTemplate.isPredicted(slots[0], at: now))
    }

    @Test func seenTwoWeeksRunningIsPredicted() {
        let now = cph("2026-10-05 12:00")
        let slots = fold([[airing("s", "p1", "2026-09-28 07:05", 55, false, nil)],
                          [airing("s", "p1", "2026-10-05 07:05", 55, false, nil)]], now: now)
        #expect(slots.count == 1)
        #expect(WeeklyTemplate.isPredicted(slots[0], at: now))
    }

    /// The P5 special on 5 October: a one-off in the regular programme's slot. "Two of the
    /// last three weeks" keeps the regular programme predicted and the special not.
    @Test func aOneOffNeitherIsPredictedNorKnocksOutTheRegular() {
        let now = cph("2026-10-12 12:00")
        let slots = fold([[airing("regular", "p5", "2026-09-28 10:00", 55, false, nil)],
                          [airing("special", "p5", "2026-10-05 10:00", 55, false, nil)],
                          [airing("regular", "p5", "2026-10-12 10:00", 55, false, nil)]], now: now)
        let regular = slots.first { $0.seriesID == ShowTestSupport.seriesID("regular") }!
        let special = slots.first { $0.seriesID == ShowTestSupport.seriesID("special") }!
        #expect(WeeklyTemplate.isPredicted(regular, at: now))
        #expect(!WeeklyTemplate.isPredicted(special, at: now))
    }

    /// Three weeks to the day is outside the window, so a show seen then and once since is
    /// not predicted — and its old sighting is dropped when the template is next folded.
    @Test func sightingsAgeOutAfterThreeWeeks() {
        let now = cph("2026-10-19 12:00")
        let slots = fold([[airing("s", "p1", "2026-09-28 07:05", 55, false, nil)],
                          [airing("s", "p1", "2026-10-19 07:05", 55, false, nil)]], now: now)
        #expect(slots.first?.seenDates == ["2026-10-19"])
        #expect(!WeeklyTemplate.isPredicted(slots[0], at: now))
    }

    @Test func aSlotWithNoSightingsLeftIsDropped() {
        let old = fold([[airing("s", "p1", "2026-09-07 07:05", 55, false, nil)]],
                       now: cph("2026-09-07 12:00"))
        let later = WeeklyTemplate.fold([airing("t", "p1", "2026-10-05 08:00", 55, false, nil)],
                                        into: old, now: cph("2026-10-05 12:00"))
        #expect(later.map(\.seriesID) == [ShowTestSupport.seriesID("t")])
    }

    @Test func theWeekdayRepeatsNotTheDay() {
        let now = cph("2026-10-06 12:00")
        let slots = fold([[airing("s", "p1", "2026-10-05 07:05", 55, false, nil)],
                          [airing("s", "p1", "2026-10-06 07:05", 55, false, nil)]], now: now)
        #expect(slots.count == 2)
        #expect(slots.allSatisfy { !WeeklyTemplate.isPredicted($0, at: now) })
    }

    /// Learnt in summer time, predicted in winter time: still 07:05 in Copenhagen.
    @Test func aPredictionKeepsItsWallClockTimeAcrossTheClockChange() {
        let slots = fold([[airing("s", "p1", "2026-10-12 07:05", 55, false, nil)],
                          [airing("s", "p1", "2026-10-19 07:05", 55, false, nil)]],
                         now: cph("2026-10-19 12:00"))
        let next = WeeklyTemplate.nextPredicted(seriesID: ShowTestSupport.seriesID("s"),
                                                in: slots, realChannels: [],
                                                after: cph("2026-10-20 12:00"))
        #expect(next?.start == cph("2026-10-26 07:05"))
    }

    @Test func theNextPredictionIsTheSoonestSlotAfterNow() {
        let learnt = cph("2026-10-07 12:00")
        let slots = fold([[airing("s", "p1", "2026-09-28 07:05", 55, false, nil),
                           airing("s", "p1", "2026-09-30 21:00", 55, false, nil)],
                          [airing("s", "p1", "2026-10-05 07:05", 55, false, nil),
                           airing("s", "p1", "2026-10-07 21:00", 55, false, nil)]], now: learnt)
        // Thursday: Monday's slot has passed, Wednesday's too; next is Monday 12 October.
        let next = WeeklyTemplate.nextPredicted(seriesID: ShowTestSupport.seriesID("s"),
                                                in: slots, realChannels: [],
                                                after: cph("2026-10-08 09:00"))
        #expect(next?.start == cph("2026-10-12 07:05"))
    }

    /// Where today's real schedule is known, the template's guess about today is ignored.
    @Test func todaysRealScheduleOverridesTodaysPrediction() {
        let slots = fold([[airing("s", "p1", "2026-09-28 20:00", 55, false, nil)],
                          [airing("s", "p1", "2026-10-05 20:00", 55, false, nil)]],
                         now: cph("2026-10-05 21:00"))
        let now = cph("2026-10-12 09:00")
        let guessed = WeeklyTemplate.nextPredicted(seriesID: ShowTestSupport.seriesID("s"),
                                                   in: slots, realChannels: [], after: now)
        let known = WeeklyTemplate.nextPredicted(seriesID: ShowTestSupport.seriesID("s"),
                                                 in: slots, realChannels: ["p1"], after: now)
        #expect(guessed?.start == cph("2026-10-12 20:00"))
        #expect(known?.start == cph("2026-10-19 20:00"))
    }
}

/// When a favourite show is next on, in the order the shelf asks (F33).
@MainActor
struct ShowAiringTests {
    private let cph = ShowTestSupport.cph
    private let airing = ShowTestSupport.airing
    private let id = ShowTestSupport.seriesID("s")

    private func next(today: [String: [DREpisode]], slots: [TemplateSlot] = [],
                      at now: String) -> ShowAiring {
        ShowAiring.next(for: id, today: today, slots: slots, channelSlugs: ["p1"], now: cph(now))
    }

    private var predictedSlots: [TemplateSlot] {
        [[airing("s", "p3", "2026-09-29 07:05", 55, false, nil)],
         [airing("s", "p3", "2026-10-06 07:05", 55, false, nil)]]
            .reduce([]) { WeeklyTemplate.fold($1, into: $0, now: cph("2026-10-06 12:00")) }
    }

    @Test func onNowComesFirst() {
        let today = ["p1": [airing("s", "p1", "2026-10-05 07:05", 55, true, nil),
                            airing("s", "p1", "2026-10-05 12:00", 55, false, nil),
                            airing("s", "p1", "2026-10-05 22:03", 55, false, nil)]]
        let result = next(today: today, at: "2026-10-05 12:10")
        #expect(result == .onNow(today["p1"]![1]))
    }

    @Test func thenLaterToday() {
        let today = ["p1": [airing("s", "p1", "2026-10-05 07:05", 55, true, nil),
                            airing("s", "p1", "2026-10-05 22:03", 55, false, nil)]]
        #expect(next(today: today, slots: predictedSlots, at: "2026-10-05 12:10")
                == .laterToday(today["p1"]![1]))
    }

    @Test func thenThePredictedAiring() {
        let today = ["p1": [airing("s", "p1", "2026-10-05 07:05", 55, true, nil)]]
        guard case .usually(let slot, let start) = next(today: today, slots: predictedSlots,
                                                        at: "2026-10-05 12:10") else {
            Issue.record("expected a predicted airing")
            return
        }
        #expect(slot.channelSlug == "p3")
        #expect(start == cph("2026-10-06 07:05"))
    }

    @Test func thenEarlierTodayIfItCanBeListenedBackTo() {
        let today = ["p1": [airing("s", "p1", "2026-10-05 07:05", 55, true, nil)]]
        #expect(next(today: today, at: "2026-10-05 12:10") == .earlierToday(today["p1"]![0]))
    }

    @Test func earlierWithoutARecordingIsNotOnAgainToday() {
        let today = ["p1": [airing("s", "p1", "2026-10-05 07:05", 55, false, nil)]]
        #expect(next(today: today, at: "2026-10-05 12:10") == .notOnAgainToday)
    }

    @Test func aChannelFetchedWithoutTheShowIsNotOnAgainToday() {
        let today = ["p1": [airing("other", "p1", "2026-10-05 07:05", 55, false, nil)]]
        #expect(next(today: today, at: "2026-10-05 12:10") == .notOnAgainToday)
    }

    @Test func nothingFetchedIsUnknown() {
        #expect(next(today: [:], at: "2026-10-05 12:10") == .unknown)
    }

    /// Past midnight, the evening's programmes are still today's broadcast day.
    @Test func afterMidnightTheEarlyHoursAiringIsLaterToday() {
        let today = ["p1": [airing("s", "p1", "2026-10-06 01:00", 55, false, nil)]]
        #expect(next(today: today, at: "2026-10-06 00:30") == .laterToday(today["p1"]![0]))
    }
}
