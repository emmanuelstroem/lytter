//
//  UserPreferencesService.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import Foundation
import Combine

class UserPreferencesService: ObservableObject {
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Keys
    private enum Keys {
        static let lastPlayedChannelId = "lastPlayedChannelId"
        static let lastPlayedChannelTitle = "lastPlayedChannelTitle"
        static let lastPlayedChannelDistrict = "lastPlayedChannelDistrict"
        static let lastPlayedChannelName = "lastPlayedChannelName"
        static let lastPlayedTimestamp = "lastPlayedTimestamp"
    }
    
    // MARK: - Published Properties
    @Published var lastPlayedChannel: DRChannel?
    @Published var lastPlayedTimestamp: Date?
    
    init() {
        loadLastPlayedChannel()
    }
    
    // MARK: - Save Last Played Channel
    func saveLastPlayedChannel(_ channel: DRChannel) {
        userDefaults.set(channel.id, forKey: Keys.lastPlayedChannelId)
        userDefaults.set(channel.title, forKey: Keys.lastPlayedChannelTitle)
        userDefaults.set(channel.district, forKey: Keys.lastPlayedChannelDistrict)
        userDefaults.set(channel.name, forKey: Keys.lastPlayedChannelName)
        userDefaults.set(Date(), forKey: Keys.lastPlayedTimestamp)
        
        lastPlayedChannel = channel
        lastPlayedTimestamp = Date()
    }
    
    // MARK: - Load Last Played Channel
    private func loadLastPlayedChannel() {
        guard let channelId = userDefaults.string(forKey: Keys.lastPlayedChannelId),
              let channelTitle = userDefaults.string(forKey: Keys.lastPlayedChannelTitle),
              let channelName = userDefaults.string(forKey: Keys.lastPlayedChannelName) else {
            return
        }
        
        _ = userDefaults.string(forKey: Keys.lastPlayedChannelDistrict)
        let timestamp = userDefaults.object(forKey: Keys.lastPlayedTimestamp) as? Date
        
        let channel = DRChannel(
            id: channelId,
            title: channelTitle,
            slug: channelName.lowercased().replacingOccurrences(of: " ", with: ""),
            type: "radio",
            presentationUrl: nil
        )
        
        lastPlayedChannel = channel
        lastPlayedTimestamp = timestamp
    }
    
    // MARK: - Find Last Played Channel in Available Channels
    func findLastPlayedChannel(in availableChannels: [DRChannel]) -> DRChannel? {
        guard let lastPlayed = lastPlayedChannel else { return nil }
        
        // Try to find exact match by ID
        if let exactMatch = availableChannels.first(where: { $0.id == lastPlayed.id }) {
            return exactMatch
        }
        
        // Try to find by title and name (in case ID changed)
        if let titleMatch = availableChannels.first(where: { 
            $0.title == lastPlayed.title && $0.name == lastPlayed.name 
        }) {
            return titleMatch
        }
        
        // Try to find by name only
        if let nameMatch = availableChannels.first(where: { $0.name == lastPlayed.name }) {
            return nameMatch
        }
        
        return nil
    }
    
    // MARK: - Clear Last Played Channel
    func clearLastPlayedChannel() {
        userDefaults.removeObject(forKey: Keys.lastPlayedChannelId)
        userDefaults.removeObject(forKey: Keys.lastPlayedChannelTitle)
        userDefaults.removeObject(forKey: Keys.lastPlayedChannelDistrict)
        userDefaults.removeObject(forKey: Keys.lastPlayedChannelName)
        userDefaults.removeObject(forKey: Keys.lastPlayedTimestamp)
        
        lastPlayedChannel = nil
        lastPlayedTimestamp = nil
    }
    
    // MARK: - Check if Last Played is Recent
    func isLastPlayedRecent(within hours: Int = 24) -> Bool {
        guard let timestamp = lastPlayedTimestamp else { return false }
        let timeInterval = TimeInterval(hours * 3600)
        return Date().timeIntervalSince(timestamp) < timeInterval
    }
} 