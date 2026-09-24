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
}
