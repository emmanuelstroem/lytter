//
//  ContentProvider.swift
//  TopShelfExtension
//
//  Created by Emmanuel on 09/08/2025.
//

import TVServices
import Foundation

class ContentProvider: TVTopShelfContentProvider {
    private let networkService = TopShelfNetworkService()

    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        // Create dynamic content with live channel data and images
        return await createRadioContent()
    }
    
    private func createRadioContent() async -> TVTopShelfSectionedContent {
        // Fetch live channel data with images
        let radioItems = await createRadioItems()
        
        // Create single section with all radio channels
        let radioSection = TVTopShelfItemCollection<TVTopShelfSectionedItem>(items: radioItems)
        radioSection.title = "DR Radio"
        
        return TVTopShelfSectionedContent(sections: [radioSection])
    }
    
    private func createRadioItems() async -> [TVTopShelfSectionedItem] {
        do {
            // Fetch live channel data
            let episodes = try await networkService.fetchChannelsWithImages()
            
            // Group channels and consolidate districts
            let consolidatedChannels = consolidateChannelsByName(episodes)
            
            var items: [TVTopShelfSectionedItem] = []
            
            for episode in consolidatedChannels {
                let item = TVTopShelfSectionedItem(identifier: episode.id)
                item.title = episode.title
                
                // Use live image from API
                if let imageURLString = episode.primaryImageURL,
                   let imageURL = URL(string: imageURLString) {
                    item.setImageURL(imageURL, for: .screenScale1x)
                    item.setImageURL(imageURL, for: .screenScale2x)
                } else {
                    // Fallback to bundled images if API doesn't have image
                    await setFallbackImage(for: item, channelSlug: episode.channel.slug)
                }
                
                // Set up deep link actions
                if let deepLinkURL = createDeepLinkURL(channelId: episode.channel.slug) {
                    item.displayAction = TVTopShelfAction(url: deepLinkURL)
                    item.playAction = TVTopShelfAction(url: deepLinkURL)
                }
                
                items.append(item)
            }
            
            return items
            
        } catch {
            print("⚠️ TopShelf: Failed to fetch live data, using fallback: \(error)")
            return await createFallbackItems()
        }
    }
    
    private func consolidateChannelsByName(_ episodes: [TopShelfEpisode]) -> [TopShelfEpisode] {
        var consolidatedChannels: [String: TopShelfEpisode] = [:]
        
        for episode in episodes {
            let channelName = episode.channel.name
            
            // Priority order: P1, P2, P3, P4 (prefer København), P5 (prefer København)
            if consolidatedChannels[channelName] == nil {
                consolidatedChannels[channelName] = episode
            } else if let existing = consolidatedChannels[channelName] {
                // For P4 and P5, prefer København district
                if (channelName == "P4" || channelName == "P5") && 
                   episode.channel.district?.lowercased().contains("københavn") == true {
                    consolidatedChannels[channelName] = episode
                }
            }
        }
        
        // Sort by channel priority
        let channelOrder = ["P1", "P2", "P3", "P4", "P5", "P6", "P8"]
        return consolidatedChannels.values.sorted { first, second in
            let firstIndex = channelOrder.firstIndex(of: first.channel.name) ?? 999
            let secondIndex = channelOrder.firstIndex(of: second.channel.name) ?? 999
            return firstIndex < secondIndex
        }
    }
    
    private func setFallbackImage(for item: TVTopShelfSectionedItem, channelSlug: String) async {
        let fallbackImages: [String: String] = [
            "p1": "P1",
            "p2": "P2", 
            "p3": "P3",
            "p4kbh": "P4KBH",
            "p5kbh": "P5KBH"
        ]
        
        if let imageName = fallbackImages[channelSlug.lowercased()] {
            if let imageURL = Bundle.main.url(forResource: imageName, withExtension: "png", subdirectory: "images") {
                item.setImageURL(imageURL, for: .screenScale1x)
                item.setImageURL(imageURL, for: .screenScale2x)
            }
        }
    }
    
    private func createFallbackItems() async -> [TVTopShelfSectionedItem] {
        var items: [TVTopShelfSectionedItem] = []
        
        // Fallback static channels if network fails
        let fallbackChannels = [
            ("p1", "DR P1", "P1"),
            ("p2", "DR P2", "P2"),
            ("p3", "DR P3", "P3"),
            ("p4kbh", "DR P4 København", "P4KBH"),
            ("p5kbh", "DR P5 København", "P5KBH")
        ]
        
        for (channelId, title, imageName) in fallbackChannels {
            let item = TVTopShelfSectionedItem(identifier: channelId)
            item.title = title
            
            await setFallbackImage(for: item, channelSlug: channelId)
            
            if let deepLinkURL = createDeepLinkURL(channelId: channelId) {
                item.displayAction = TVTopShelfAction(url: deepLinkURL)
                item.playAction = TVTopShelfAction(url: deepLinkURL)
            }
            
            items.append(item)
        }
        
        return items
    }
    
    // Helper method to create deep link URLs
    private func createDeepLinkURL(channelId: String) -> URL? {
        var deepLinkComponents = URLComponents()
        deepLinkComponents.scheme = "lytter"
        deepLinkComponents.host = "radio"
        deepLinkComponents.path = "/channel/\(channelId)"
        return deepLinkComponents.url
    }

}