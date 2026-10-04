//
//  ScheduleIndexTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// The schedule is looked up by channel from view bodies, so it is indexed once per refresh
/// rather than filtered per call (P6). The index has to give the same answers the filter did.
///
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct ScheduleIndexTests {

    private func programme(_ id: String, on channel: String) -> DREpisode {
        DREpisode(type: "Episode", learnId: id, durationMilliseconds: 0, categories: nil,
                  productionNumber: nil, startTime: "2026-10-04T08:00:00+00:00",
                  endTime: "2026-10-04T09:00:00+00:00", presentationUrl: nil,
                  order: 0, previousId: nil, nextId: nil, series: nil,
                  channel: DRChannel(id: "urn:\(channel)", title: channel, slug: channel,
                                     type: "Channel", presentationUrl: nil),
                  audioAssets: nil, isAvailableOnDemand: false, hasVideo: false,
                  explicitContent: false, id: id, slug: id, title: id, description: nil,
                  imageAssets: nil, episodeNumber: nil, seasonNumber: nil)
    }

    private var schedule: [DREpisode] {
        [programme("p1-a", on: "p1"), programme("p3-a", on: "p3"),
         programme("p1-b", on: "p1"), programme("p3-b", on: "p3"), programme("p1-c", on: "p1")]
    }

    @Test func eachChannelHasOnlyItsOwnProgrammes() {
        let index = DRServiceManager.indexByChannel(schedule)
        #expect(index["urn:p1"]?.map(\.id) == ["p1-a", "p1-b", "p1-c"])
        #expect(index["urn:p3"]?.map(\.id) == ["p3-a", "p3-b"])
    }

    /// The lookups take the first match, so reordering would change which programme shows.
    @Test func matchesFilteringTheWholeSchedule() {
        let index = DRServiceManager.indexByChannel(schedule)
        for channel in ["urn:p1", "urn:p3"] {
            #expect(index[channel]?.map(\.id) == schedule.filter { $0.channel.id == channel }.map(\.id))
        }
    }

    @Test func aChannelWithNoProgrammesIsAbsent() {
        #expect(DRServiceManager.indexByChannel(schedule)["urn:p6"] == nil)
        #expect(DRServiceManager.indexByChannel([]).isEmpty)
    }
}
