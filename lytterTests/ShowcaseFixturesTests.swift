//
//  ShowcaseFixturesTests.swift
//  lytterTests
//

import AVFoundation
import Foundation
import Testing
@testable import lytter

/// The App Store screenshots' data (`UITestFixtures+Showcase`) reads as radio, never as a
/// test, and its silence is a file AVPlayer can play.
@MainActor
struct ShowcaseFixturesTests {

    /// A station of every kind the showcase tells apart, and two regions of each regional one.
    private let slugs = ["p1", "p2", "p3", "p4fyn", "p4københavn", "p5bornholm", "p5syd",
                         "p6"]

    /// The plain fixtures' words, which a screenshot must not show.
    private let testWords = ["fixture", "test", "beskrivelse af program"]

    @Test func everyStationHasADayOfProgrammesInWords() {
        for slug in slugs {
            let station = UITestFixtures.showcaseStation(for: slug)
            #expect(station.programmes.count == 10, "\(slug)")
            let text = (station.programmes + [station.description,
                                              station.track?.artist ?? "",
                                              station.track?.title ?? ""])
                .joined(separator: " ").lowercased()
            for word in testWords {
                #expect(!text.contains(word), "\(slug) says \"\(word)\"")
            }
        }
    }

    /// P1 talks; the rest play music, and the player shows what.
    @Test func onlyTheTalkStationHasNoTrack() {
        #expect(UITestFixtures.showcaseStation(for: "p1").track == nil)
        for slug in slugs where slug != "p1" {
            #expect(UITestFixtures.showcaseStation(for: slug).track != nil, "\(slug)")
        }
    }

    /// A favourite show is found by its series, in its own station's namespace, so the
    /// same programme number on two stations is two shows.
    @Test func favouriteShowsAreTheirStationsProgrammes() {
        for show in UITestFixtures.showcaseFavouriteShows {
            let series = UITestFixtures.showcaseSeries(show.index, slug: show.slug)
            #expect(series.title == UITestFixtures.showcaseStation(for: show.slug)
                        .programmes[show.index])
            #expect(series.id == UITestFixtures.showcaseSeriesID(show.index, slug: show.slug))
        }
        #expect(UITestFixtures.showcaseSeriesID(5, slug: "p1")
                != UITestFixtures.showcaseSeriesID(5, slug: "p3"))
    }

    /// Twenty minutes, longer than any screenshot run: a stream that ended mid-run would
    /// show the player stopped.
    @Test func theSilenceIsTwentyMinutesOfPlayableAudio() async throws {
        let url = try #require(URL(string: UITestFixtures.showcaseStreamURL))
        let asset = AVURLAsset(url: url)
        #expect(try await asset.load(.isPlayable))
        let duration = try await asset.load(.duration)
        #expect(abs(duration.seconds - 20 * 60) < 1, "\(duration.seconds) s")
    }
}
