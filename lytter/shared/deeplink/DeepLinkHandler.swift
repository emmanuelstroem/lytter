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
            
            // Store the pending channel ID for retry if needed
            self.pendingChannelId = channelId
            
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
            
            // Store the pending channel ID for retry if needed
            self.pendingChannelId = channelId
            
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
    }
    
    func retryPendingDeepLink() {
        if let channelId = pendingChannelId {
            Log.deepLink.debug("retrying pending link for \(channelId, privacy: .private)")
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
        }
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
