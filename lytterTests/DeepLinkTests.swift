//
//  DeepLinkTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// The share sheet handed out `lyt:///channel/<id>` for months while Info.plist
/// registered only `lytter`, so every shared link was inert — iOS does not deliver an
/// unregistered scheme to anybody, and the handler accepting `lyt` hid it from review.
/// These tests pin the two invariants that would have caught it.
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION
/// = MainActor, so the types under test are main-actor isolated by inference. Swift 6
/// rejects calling them from a nonisolated suite.
@MainActor
struct DeepLinkTests {

    private let channel = DRChannel(
        id: "urn:dr:radio:channel:5fa156d1da351264f87b462d",
        title: "DR P1",
        slug: "p1",
        type: "Channel",
        presentationUrl: nil
    )

    /// The invariant that actually broke: what we emit has to be what we registered.
    /// `Bundle.main` is the host app here, so this reads the shipping Info.plist.
    @Test func generatedSchemeIsRegisteredInInfoPlist() throws {
        let url = try #require(DeepLinkHandler.generateDeepLinkURL(for: channel))
        let scheme = try #require(url.scheme)

        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
        let registered = (types ?? []).flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }

        #expect(registered.contains(scheme),
                "generated \(scheme):// but Info.plist registers \(registered)")
    }

    @Test func generatedLinkResolvesToTheChannel() {
        let handler = DeepLinkHandler()
        let url = URL(string: DeepLinkHandler.generateDeepLinkString(for: channel))!

        handler.handleDeepLink(url)

        #expect(handler.pendingChannelId == channel.id)
    }

    /// The Top Shelf extension builds its URL with `radio` as the authority. That still
    /// works — the authority is not part of `URLComponents.path` — and this pins it, so
    /// the two link shapes cannot drift apart unnoticed.
    @Test func topShelfLinkResolvesToTheChannel() {
        let handler = DeepLinkHandler()

        handler.handleDeepLink(URL(string: "lytter://radio/channel/p1")!)

        #expect(handler.pendingChannelId == "p1")
    }

    /// Dropping the third slash moves `channel` into the authority and leaves a path the
    /// handler matches nothing against. The link then fails silently, which is the trap
    /// worth having a test for.
    @Test func linkWithoutAnEmptyAuthorityIsNotAccepted() {
        let handler = DeepLinkHandler()

        handler.handleDeepLink(URL(string: "lytter://channel/p1")!)

        #expect(handler.pendingChannelId == nil)
    }

    @Test func unregisteredSchemeIsRejected() {
        let handler = DeepLinkHandler()

        handler.handleDeepLink(URL(string: "lyt:///channel/p1")!)

        #expect(handler.pendingChannelId == nil)
    }

    // MARK: - Pending link lifecycle

    /// A link opened from cold arrives before the catalogue, so it has to stay pending
    /// long enough to be retried. It used to be cleared on that first failed attempt,
    /// which is why cold-start links never resolved.
    @Test func aFreshLinkSurvivesForRetry() {
        let handler = DeepLinkHandler()

        handler.handleDeepLink(URL(string: "lytter:///channel/p1")!)

        #expect(handler.pendingChannelId == "p1")
        #expect(handler.isPendingLinkWorthRetrying)
    }

    @Test func clearingALinkEndsItsRetryWindow() {
        let handler = DeepLinkHandler()
        handler.handleDeepLink(URL(string: "lytter:///channel/p1")!)

        handler.clearTarget()

        #expect(handler.pendingChannelId == nil)
        #expect(!handler.isPendingLinkWorthRetrying)
    }

    // MARK: - Identifier validation

    @Test(arguments: [
        "p1",
        "urn:dr:radio:channel:5fa156d1da351264f87b462d",
        "p4kbh",
    ])
    func realIdentifiersAreAccepted(identifier: String) {
        #expect(DeepLinkHandler.isPlausibleIdentifier(identifier))
    }

    /// Deep links are attacker-supplied: anything on the device can hand us a URL. These
    /// are rejected before an identifier is stored and retried.
    @Test func implausibleIdentifiersAreRejected() {
        #expect(!DeepLinkHandler.isPlausibleIdentifier(""))
        #expect(!DeepLinkHandler.isPlausibleIdentifier(
            String(repeating: "p", count: DeepLinkHandler.maximumIdentifierLength + 1)))
        #expect(!DeepLinkHandler.isPlausibleIdentifier("p1\nInjected"))
        #expect(!DeepLinkHandler.isPlausibleIdentifier("p1\u{0000}"))
    }

    @Test func anImplausibleIdentifierIsNeverStored() {
        let handler = DeepLinkHandler()
        let overlong = String(repeating: "p", count: DeepLinkHandler.maximumIdentifierLength + 1)

        handler.handleDeepLink(URL(string: "lytter:///channel/\(overlong)")!)

        #expect(handler.pendingChannelId == nil)
    }
}
