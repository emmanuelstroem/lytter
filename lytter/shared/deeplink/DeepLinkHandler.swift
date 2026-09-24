//
//  DeepLinkHandler.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import SwiftUI
import Combine
import os

// MARK: - Deep Link Handler
class DeepLinkHandler: ObservableObject {
    /// The URL scheme this app answers to. Must stay in step with `CFBundleURLSchemes`
    /// in Info.plist; `DeepLinkTests` asserts that it does.
    static let urlScheme = "lytter"

    /// How long an unresolved link is worth holding on to.
    ///
    /// A link opened from cold arrives before the catalogue does, so it has to survive
    /// long enough to be retried once channels load. Past that window it names a channel
    /// that is not in the catalogue at all, and holding it would re-fire on every
    /// catalogue refresh for the rest of the session.
    static let pendingLinkTimeout: TimeInterval = 30

    /// The longest channel identifier worth storing. Real ones are slugs (`p1`) or URNs
    /// of about 45 characters; anything beyond this is not a channel we could resolve.
    static let maximumIdentifierLength = 256

    private var pendingSince: Date?

    /// Whether an unresolved link is still young enough to retry.
    var isPendingLinkWorthRetrying: Bool {
        guard pendingChannelId != nil, let pendingSince else { return false }
        return Date().timeIntervalSince(pendingSince) < Self.pendingLinkTimeout
    }

    @Published var targetChannel: DRChannel?
    @Published var shouldNavigateToChannel = false
    @Published var pendingChannelId: String?
    
    func handleDeepLink(_ url: URL) {
        Log.deepLink.debug("received \(url.absoluteString, privacy: .private)")
        // Only the scheme Info.plist registers. "lyt" used to be accepted here too, which
        // is why nobody noticed that the share sheet was emitting it: the handler was
        // happy to take those URLs, but iOS never routed one to us, because an
        // unregistered scheme is not delivered to anybody.
        guard url.scheme == DeepLinkHandler.urlScheme else {
            Log.deepLink.warning("rejected URL with unknown scheme")
            return
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let rawPathComponents = components?.path.components(separatedBy: "/") ?? []
        let pathComponents = rawPathComponents.filter { !$0.isEmpty }
        
        
        // Handle different path structures: /channel/id, channel/id, and radio/channel/id
        if pathComponents.count >= 2 && pathComponents[0] == "channel" {
            let channelId = pathComponents[1]
            Log.deepLink.debug("resolving channel \(channelId, privacy: .private)")
            
            guard Self.isPlausibleIdentifier(channelId) else {
                Log.deepLink.warning("rejected an implausible channel identifier")
                return
            }

            // Store the pending channel ID for retry if needed
            self.pendingChannelId = channelId
            self.pendingSince = Date()
            
            // Create a placeholder channel that will be replaced with the actual channel
            // when the app finds it in the available channels
            DispatchQueue.main.async {
                self.targetChannel = DRChannel(
                    id: channelId,
                    title: "Channel \(channelId)",
                    slug: channelId,
                    type: "Channel",
                    presentationUrl: nil
                )
                self.shouldNavigateToChannel = true
            }
        } else if pathComponents.count >= 3 && pathComponents[0] == "radio" && pathComponents[1] == "channel" {
            // Handle TopShelf format: /radio/channel/id
            let channelId = pathComponents[2]
            Log.deepLink.debug("resolving Top Shelf channel \(channelId, privacy: .private)")
            
            guard Self.isPlausibleIdentifier(channelId) else {
                Log.deepLink.warning("rejected an implausible channel identifier")
                return
            }

            // Store the pending channel ID for retry if needed
            self.pendingChannelId = channelId
            self.pendingSince = Date()
            
            // Create a placeholder channel that will be replaced with the actual channel
            // when the app finds it in the available channels
            DispatchQueue.main.async {
                self.targetChannel = DRChannel(
                    id: channelId,
                    title: "Channel \(channelId)",
                    slug: channelId,
                    type: "Channel",
                    presentationUrl: nil
                )
                self.shouldNavigateToChannel = true
            }
        } else {
            Log.deepLink.warning("URL did not match any known path shape")
        }
    }
    
    func clearTarget() {
        targetChannel = nil
        shouldNavigateToChannel = false
        pendingChannelId = nil
        pendingSince = nil
    }

    /// Rejects identifiers that could not name a channel, before one is stored and
    /// retried. Deep links are attacker-supplied input: anything can send us a URL.
    static func isPlausibleIdentifier(_ identifier: String) -> Bool {
        guard !identifier.isEmpty, identifier.count <= maximumIdentifierLength else {
            return false
        }
        return !identifier.contains { $0.isNewline || $0.unicodeScalars.contains { s in
            s.properties.generalCategory == .control
        } }
    }
    
}

// MARK: - Deep Link URL Generator
extension DeepLinkHandler {
    /// Builds the link shared from the player, e.g. `lytter:///channel/<id>`.
    ///
    /// Note the three slashes. The authority has to be empty, because `handleDeepLink`
    /// reads `URLComponents.path`: in `lytter://channel/<id>` the parser takes `channel`
    /// as the host and leaves `/<id>` as the path, so the link matches nothing and does
    /// nothing. The Top Shelf extension's `lytter://radio/channel/<slug>` works for the
    /// same reason in reverse — its `radio` host is dropped and the path is already
    /// `/channel/<slug>`.
    static func generateDeepLinkString(for channel: DRChannel) -> String {
        "\(urlScheme):///channel/\(channel.id)"
    }

    /// The same link as a `URL`.
    static func generateDeepLinkURL(for channel: DRChannel) -> URL? {
        URL(string: generateDeepLinkString(for: channel))
    }
} 
