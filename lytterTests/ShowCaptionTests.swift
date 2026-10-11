//
//  ShowCaptionTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// The line under a favourite show's card is its time alone: the card names its station
/// already. VoiceOver, which reads the card as one element, still hears the station.
@MainActor
struct ShowCaptionTests {

    private let episode = ShowTestSupport.airing("orientering", on: "p1", at: "2026-10-05 22:03")

    private func channelTitle(_ slug: String) -> String { slug.uppercased() }

    @Test func onNowNamesNoStation() {
        let airing = ShowAiring.onNow(episode)
        #expect(airing.timeCaption == String(localized: "On now"))
        #expect(!airing.timeCaption.contains("P1"))
        #expect(airing.caption(channelTitle: channelTitle).contains("P1"))
    }

    @Test func laterTodayIsTheTimeAlone() throws {
        let airing = ShowAiring.laterToday(episode)
        let start = try #require(episode.startDate)
        #expect(airing.timeCaption == start.formatted(date: .omitted, time: .shortened))
        #expect(airing.caption(channelTitle: channelTitle).contains("P1"))
    }

    /// The rest name no station, so the card's line is the full one.
    @Test func theRestAreAsTheCaption() {
        for airing in [ShowAiring.earlierToday(episode), .notOnAgainToday, .unknown] {
            #expect(airing.timeCaption == airing.caption(channelTitle: channelTitle))
        }
    }
}
