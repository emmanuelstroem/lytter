//
//  DeepLinkHandler.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import SwiftUI
import Combine

// MARK: - Deep Link Handler
class DeepLinkHandler: ObservableObject {
    @Published var targetChannel: DRChannel?
    @Published var shouldNavigateToChannel = false
    @Published var pendingChannelId: String?
    
    func handleDeepLink(_ url: URL) {
        print("🔗 DeepLinkHandler: Received URL: \(url)")
        guard url.scheme == "lyt" else { 
            print("🔗 DeepLinkHandler: Invalid scheme: \(url.scheme ?? "nil")")
            return 
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let rawPathComponents = components?.path.components(separatedBy: "/") ?? []
        let pathComponents = rawPathComponents.filter { !$0.isEmpty }
        
        print("🔗 DeepLinkHandler: Raw path components: \(rawPathComponents)")
        print("🔗 DeepLinkHandler: Filtered path components: \(pathComponents)")
        print("🔗 DeepLinkHandler: Full path: \(components?.path ?? "nil")")
        
        // Handle both formats: /channel/id and channel/id
        if pathComponents.count >= 2 && pathComponents[0] == "channel" {
            let channelId = pathComponents[1]
            print("🔗 DeepLinkHandler: Processing channel ID: \(channelId)")
            
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
                print("🔗 DeepLinkHandler: Set target channel and shouldNavigateToChannel = true")
            }
        } else {
            print("🔗 DeepLinkHandler: Invalid path structure")
        }
    }
    
    func clearTarget() {
        targetChannel = nil
        shouldNavigateToChannel = false
        pendingChannelId = nil
    }
    
    func retryPendingDeepLink() {
        if let channelId = pendingChannelId {
            print("🔗 DeepLinkHandler: Retrying pending deep link for channel: \(channelId)")
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
        print("🔗 DeepLinkHandler: Generating URL: \(urlString)")
        return URL(string: urlString)
    }
    
    /// Generates a deep link URL string for a specific channel
    /// - Parameter channel: The channel to create a deep link for
    /// - Returns: A URL string that will open the app and navigate to the channel
    static func generateDeepLinkString(for channel: DRChannel) -> String {
        let urlString = "lyt:///channel/\(channel.id)"
        print("🔗 DeepLinkHandler: Generating URL string: \(urlString)")
        return urlString
    }
} 
