//
//  FavouritesTests.swift
//  lytterTests
//

import Testing
@testable import lytter

/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct FavouritesTests {

    private func channel(_ id: String, _ title: String = "T") -> DRChannel {
        DRChannel(id: id, title: title, slug: id, type: "Channel", presentationUrl: nil)
    }

    @Test func addingKeepsInsertionOrder() {
        var favourites = Favourites()
        favourites.add("p3")
        favourites.add("p1")
        favourites.add("p4kbh")

        #expect(favourites.channelIDs == ["p3", "p1", "p4kbh"])
    }

    @Test func addingTwiceDoesNothing() {
        var favourites = Favourites()
        favourites.add("p1")
        favourites.add("p1")

        #expect(favourites.channelIDs == ["p1"])
    }

    @Test func togglingReportsTheNewState() {
        var favourites = Favourites()

        let added = favourites.toggle("p1")
        let removed = favourites.toggle("p1")

        #expect(added)
        #expect(!removed)
        #expect(favourites.isEmpty)
    }

    /// A persisted list that somehow gained duplicates would render as two identical cards.
    @Test func duplicatesInStoredDataAreDropped() {
        let favourites = Favourites(channelIDs: ["p1", "p3", "p1"])

        #expect(favourites.channelIDs == ["p1", "p3"])
    }

    /// Favourite order, not catalogue order — the whole point is that the list is yours.
    @Test func resolvingUsesFavouriteOrder() {
        let favourites = Favourites(channelIDs: ["p4kbh", "p1"])
        let catalogue = [channel("p1"), channel("p3"), channel("p4kbh")]

        #expect(favourites.resolve(in: catalogue).map(\.id) == ["p4kbh", "p1"])
    }

    /// DR retires channels. A stale id should vanish rather than leave a gap.
    @Test func idsTheCatalogueNoLongerHasAreDropped() {
        let favourites = Favourites(channelIDs: ["p1", "p7-retired"])

        #expect(favourites.resolve(in: [channel("p1")]).map(\.id) == ["p1"])
    }

    @Test func removingSomethingAbsentIsHarmless() {
        var favourites = Favourites(channelIDs: ["p1"])
        favourites.remove("p3")

        #expect(favourites.channelIDs == ["p1"])
    }
}
