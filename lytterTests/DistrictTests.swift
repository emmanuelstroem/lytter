//
//  DistrictTests.swift
//  lytterTests
//

import Testing
@testable import lytter

/// A listener has one region, and two stations broadcast it. The point of `District` having
/// an identifier at all is that a region chosen on P4 can be found again on P5 — so these
/// concentrate on that crossing, and on the ways a stored region can fail to resolve.
///
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct DistrictTests {

    private func channel(_ title: String) -> DRChannel {
        DRChannel(id: title.lowercased(), title: title, slug: title.lowercased(),
                  type: "Channel", presentationUrl: nil)
    }

    private var p4: GroupedChannel {
        GroupedChannel(channels: ["P4 København", "P4 Fyn", "P4 Midt & Vest"].map(channel))
    }

    private var p5: GroupedChannel {
        GroupedChannel(channels: ["P5 København", "P5 Fyn", "P5 Midt & Vest"].map(channel))
    }

    // MARK: - Identity

    @Test func theSameRegionOnTwoStationsIsOneRegion() {
        let onP4 = District(name: "København")
        let onP5 = District(name: "København")

        #expect(onP4 == onP5)
        #expect(onP4.id == onP5.id)
    }

    @Test func differentRegionsAreNotEqual() {
        #expect(District(name: "København") != District(name: "Fyn"),
                "two regions collapsing into one would play the wrong signal")
    }

    /// Restyling a name must not create a new region, or a stored one stops resolving and
    /// the listener is silently asked again.
    @Test func identitySurvivesCasingAndSpacing() {
        #expect(District(name: "MIDT & VEST").id == District(name: "Midt & Vest").id)
        #expect(District(name: "midt vest").id == District(name: "Midt & Vest").id)
    }

    /// Danish letters are letters, so they survive rather than being stripped into a
    /// collision — "Østjylland" and "Sjælland" must not fold onto each other.
    @Test func danishLettersAreKept() {
        #expect(District(name: "Østjylland").id == "østjylland")
        #expect(District(name: "Sjælland").id != District(name: "Østjylland").id)
    }

    @Test func aRegionKeepsTheNameItWasGiven() {
        #expect(District(name: "Midt & Vest").name == "Midt & Vest",
                "the id is folded, but what the listener reads is not")
    }

    // MARK: - Crossing stations

    @Test func aRegionChosenOnOneStationIsFoundOnTheOther() {
        let chosen = District(name: "København")

        #expect(p4.channel(in: chosen)?.title == "P4 København")
        #expect(p5.channel(in: chosen)?.title == "P5 København")
    }

    @Test func aRegionTheStationDoesNotBroadcastIsNotFound() {
        let elsewhere = District(name: "Bornholm")

        #expect(p4.channel(in: elsewhere) == nil,
                "falling back to some other district would play the wrong region silently")
    }

    @Test func aMultiWordRegionCrossesToo() {
        #expect(p5.channel(in: District(name: "Midt & Vest"))?.title == "P5 Midt & Vest")
    }

    // MARK: - Channel identifiers

    @Test func aChannelWithNoDistrictHasNoRegion() {
        #expect(channel("P1").districtID == nil)
    }

    @Test func aChannelsRegionMatchesTheDistrictItNames() {
        #expect(channel("P4 København").districtID == District(name: "København").id)
    }

    // MARK: - Representatives

    /// tvOS lists one channel per station. It used to pick that itself; now it asks
    /// `GroupedChannel`, so the two must agree on the answer.
    @Test func aStationWithoutDistrictsRepresentsItself() {
        #expect(GroupedChannel(channels: [channel("P1")]).representative?.title == "P1")
    }

    @Test func aStationWithDistrictsIsRepresentedByItsFirst() {
        #expect(p4.representative?.title == "P4 Fyn",
                "ordered by display name, so the choice does not vary between launches")
    }

    @Test func soleChannelIsOnlyTheUngroupedOne() {
        #expect(GroupedChannel(channels: [channel("P3")]).soleChannel?.title == "P3")
        #expect(p4.soleChannel == nil, "a station of three stands for no single channel")
    }
}
