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
    @Published var targetChannel: DRChannel?
    @Published var shouldNavigateToChannel = false
    @Published var pendingChannelId: String?
    
    func handleDeepLink(_ url: URL) {
        Log.deepLink.debug("received \(url.absoluteString, privacy: .private)")
        guard url.scheme == "lyt" || url.scheme == "lytter" else {
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
    /// Generates a deep link URL for a specific channel
    /// - Parameter channel: The channel to create a deep link for
    /// - Returns: A URL that will open the app and navigate to the channel
    static func generateDeepLinkURL(for channel: DRChannel) -> URL? {
        let urlString = "lyt:///channel/\(channel.id)"
        return URL(string: urlString)
    }
    
    /// Generates a deep link URL string for a specific channel
    /// - Parameter channel: The channel to create a deep link for
    /// - Returns: A URL string that will open the app and navigate to the channel
    static func generateDeepLinkString(for channel: DRChannel) -> String {
        let urlString = "lyt:///channel/\(channel.id)"
        return urlString
    }
} 
