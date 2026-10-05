//
//  FavouriteShowsTests.swift
//  lytterTests
//

import Testing
@testable import lytter

/// Pinned shows (F33): kept in the order pinned, never twice, and kept up to date with
/// what DR says about them.
@MainActor
struct FavouriteShowsTests {

    private func show(_ id: String, title: String = "T", on slugs: [String] = ["p1"]) -> FavouriteShow {
        FavouriteShow(seriesID: id, title: title, imageURL: nil, channelSlugs: slugs)
    }

    @Test func addingKeepsInsertionOrder() {
        var shows = FavouriteShows()
        shows.add(show("b"))
        shows.add(show("a"))
        shows.add(show("c"))

        #expect(shows.shows.map(\.seriesID) == ["b", "a", "c"])
    }

    @Test func aShowIsPinnedOnce() {
        var shows = FavouriteShows()
        shows.add(show("a", title: "First"))
        shows.add(show("a", title: "Second"))

        #expect(shows.shows.count == 1)
        #expect(shows.shows.first?.title == "First")
    }

    @Test func aStoredListWithDuplicatesLoadsWithout() {
        let shows = FavouriteShows(shows: [show("a"), show("b"), show("a")])
        #expect(shows.shows.map(\.seriesID) == ["a", "b"])
    }

    @Test func togglingReportsTheNewState() {
        var shows = FavouriteShows()
        let added = shows.toggle(show("a"))
        let removed = shows.toggle(show("a"))

        #expect(added)
        #expect(!removed)
        #expect(shows.isEmpty)
    }

    @Test func aProgrammeWithoutASeriesCannotBePinned() {
        #expect(FavouriteShow(episode: ShowTestSupport.airing(nil, at: "2026-10-05 07:00")) == nil)
    }

    @Test func pinningFromAnAiringStoresTheSeriesAndItsChannel() {
        let airing = ShowTestSupport.airing("sorte-tal", on: "p1", at: "2026-10-05 07:05",
                                            title: "Sorte tal")
        let show = FavouriteShow(episode: airing)

        #expect(show?.seriesID == ShowTestSupport.seriesID("sorte-tal"))
        #expect(show?.title == "Sorte tal")
        #expect(show?.channelSlugs == ["p1"])
    }

    /// DR renames series, and a show can turn up on a second channel: both are picked up
    /// from the schedules the app fetches anyway.
    @Test func anAiringUpdatesTitleAndAddsItsChannel() {
        var shows = FavouriteShows(shows: [show(ShowTestSupport.seriesID("s"), title: "Old")])
        let changed = shows.update(from: ShowTestSupport.airing("s", on: "p2",
                                                                at: "2026-10-05 07:05",
                                                                title: "New"))

        #expect(changed)
        #expect(shows.shows.first?.title == "New")
        #expect(shows.shows.first?.channelSlugs == ["p1", "p2"])
    }

    @Test func anAiringOfAShowNotPinnedChangesNothing() {
        var shows = FavouriteShows(shows: [show(ShowTestSupport.seriesID("s"))])
        let changed = shows.update(from: ShowTestSupport.airing("other", at: "2026-10-05 07:05"))
        #expect(!changed)
    }

    @Test func anUnchangedAiringReportsNoChange() {
        var shows = FavouriteShows(shows: [show(ShowTestSupport.seriesID("s"), title: "Show s")])
        let changed = shows.update(from: ShowTestSupport.airing("s", on: "p1", at: "2026-10-05 07:05"))
        #expect(!changed)
    }

    @Test func channelSlugsCoverEveryShow() {
        let shows = FavouriteShows(shows: [show("a", on: ["p1"]), show("b", on: ["p3", "p1"])])
        #expect(shows.channelSlugs == ["p1", "p3"])
    }
}
