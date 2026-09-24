//
//  BroadcasterTests.swift
//  lytterTests
//

import Testing
@testable import lytter

/// The home screen is meant to read as one section per broadcaster. While DR is the only
/// source that is indistinguishable from a section called "DR" — these pin the difference,
/// so the grouping is already correct when a second source arrives.
///
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct BroadcasterTests {

    private func channel(_ id: String) -> DRChannel {
        DRChannel(id: id, title: id.uppercased(), slug: id, type: "Channel", presentationUrl: nil)
    }

    @Test func everyChannelBelongsToABroadcaster() {
        #expect(Broadcaster.supplying(channel("p1")) == .dr)
    }

    @Test func channelsBecomeOneSectionPerBroadcaster() {
        let sections = Broadcaster.sections(from: [channel("p1"), channel("p3")])

        #expect(sections.count == 1)
        #expect(sections.first?.broadcaster == .dr)
        #expect(sections.first?.channels.map(\.id) == ["p1", "p3"])
    }

    /// A broadcaster that supplies nothing is left out rather than rendered as an empty
    /// heading — which is what happens when one source fails to load and others succeed.
    @Test func aBroadcasterWithNoChannelsIsOmitted() {
        #expect(Broadcaster.sections(from: []).isEmpty)
    }

    /// Explicit ordering, not alphabetical: the national broadcaster belongs at the top
    /// whatever it happens to be called.
    @Test func sectionsFollowDisplayOrder() {
        let ordered = Broadcaster.registered.sorted { $0.displayOrder < $1.displayOrder }

        #expect(ordered.first == .dr)
        #expect(Set(Broadcaster.registered.map(\.id)).count == Broadcaster.registered.count,
                "two broadcasters sharing an id would collapse into one section")
    }

    @Test func sectionIdentityIsTheBroadcaster() {
        let section = BroadcasterSection(broadcaster: .dr, channels: [channel("p1")])

        #expect(section.id == "dr")
    }
}
