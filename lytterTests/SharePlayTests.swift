//
//  SharePlayTests.swift
//  lytterTests
//

import Foundation
import GroupActivities
import Testing
#if os(iOS) || os(macOS)
import CoreTransferable
#endif
import UniformTypeIdentifiers
@testable import lytter

/// SharePlay could be offered and never received: nothing asked for sessions, and without
/// the group-session entitlement the system would not have handed one over anyway. A call
/// cannot be placed in a simulator, so these pin what can be checked without one — the
/// entitlement, what the activity says about itself, where its channel goes, and when a
/// listener's channel change becomes everyone's.
@MainActor
struct SharePlayTests {

    private let channel = DRChannel(
        id: "urn:dr:radio:channel:5fa156d1da351264f87b462d",
        title: "DR P1",
        slug: "p1",
        type: "Channel",
        presentationUrl: "https://www.dr.dk/lyd/p1"
    )

    // MARK: The activity

    /// The missing piece that made the rest moot. Read from the source, since a test
    /// bundle cannot see the host app's signed entitlements.
    @Test func theAppIsEntitledToGroupSessions() throws {
        let entitlements = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "lytter/lytter.entitlements")
        let data = try Data(contentsOf: entitlements)
        let plist = try #require(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        #expect(plist["com.apple.developer.group-session"] as? Bool == true)
    }

    @Test func theActivityIsListenedToNotWatched() {
        let metadata = RadioShareActivity(channel: channel).metadata
        #expect(metadata.type == .listenTogether)
        #expect(metadata.title == "DR P1")
    }

    /// Someone on the call without the app is sent to DR's page for the channel.
    @Test func someoneWithoutTheAppGetsDRsPage() {
        let metadata = RadioShareActivity(channel: channel).metadata
        #expect(metadata.fallbackURL == URL(string: "https://www.dr.dk/lyd/p1"))
    }

    /// The receiving side goes the way a shared link goes, so it has to be the same link.
    @Test func aReceivedChannelResolvesLikeASharedLink() throws {
        let activity = RadioShareActivity(channel: channel)
        let url = try #require(SharePlayCoordinator.deepLinkURL(forChannelId: activity.channelId))
        #expect(url == DeepLinkHandler.generateDeepLinkURL(for: channel))

        let handler = DeepLinkHandler()
        handler.handleDeepLink(url)
        #expect(handler.pendingChannelId == channel.id)
    }

    #if os(iOS) || os(macOS)
    /// The share sheet's other destinations — Messages, Mail, copy — still get the text.
    @Test func theShareSheetStillSharesTheText() async throws {
        let shared = SharedChannel(activity: RadioShareActivity(channel: channel),
                                   text: "Listening to DR P1")
        let data = try await shared.exported(as: .utf8PlainText)
        #expect(String(decoding: data, as: UTF8.self) == "Listening to DR P1")
    }
    #endif

    // MARK: Following the session

    /// Joining while playing something else tunes to the session; it does not drag the
    /// session to what this listener happened to have on.
    @Test func joiningTunesInsteadOfOverwriting() {
        var follow = SharePlayFollow()
        let mustTune = follow.sessionChanged(to: "p1", localChannelId: "p3")
        #expect(mustTune)
        let publishes = follow.localChanged(to: "p3")
        #expect(!publishes)
    }

    @Test func onceCaughtUpALocalChangeMovesEveryone() {
        var follow = SharePlayFollow()
        _ = follow.sessionChanged(to: "p1", localChannelId: "p3")
        let publishes = follow.localChanged(to: "p1")
        #expect(!publishes)
        let publishesAgain = follow.localChanged(to: "p6")
        #expect(publishesAgain)
    }

    /// Already on the session's channel — the person who started it — nothing to tune.
    @Test func theStarterIsAlreadyTuned() {
        var follow = SharePlayFollow()
        let mustTune = follow.sessionChanged(to: "p1", localChannelId: "p1")
        #expect(!mustTune)
        let publishes = follow.localChanged(to: "p2")
        #expect(publishes)
    }

    /// Someone else moved the session: tune, and do not publish the channel being left.
    @Test func someoneElsesChangeIsFollowedNotFought() {
        var follow = SharePlayFollow()
        _ = follow.sessionChanged(to: "p1", localChannelId: "p1")
        let mustTune = follow.sessionChanged(to: "p2", localChannelId: "p1")
        #expect(mustTune)
        let publishes = follow.localChanged(to: "p2")
        #expect(!publishes)
        let publishesAgain = follow.localChanged(to: "p3")
        #expect(publishesAgain)
    }

    @Test func withNoSessionNothingIsPublished() {
        var follow = SharePlayFollow()
        let publishes = follow.localChanged(to: "p1")
        #expect(!publishes)
    }
}
