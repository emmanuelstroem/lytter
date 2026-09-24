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
        static let favouriteChannelIDs = "favouriteChannelIDs"
        static let recentlyPlayedChannelIDs = "recentlyPlayedChannelIDs"
        static let preferredDistrictName = "preferredDistrictName"
    }
    
    // MARK: - Published Properties
    @Published var lastPlayedChannel: DRChannel?
    @Published var lastPlayedTimestamp: Date?

    /// Pinned channels. Only ids are stored: a channel's title and artwork come from the
    /// catalogue, and persisting a copy would leave stale names on screen after DR renames
    /// something.
    @Published private(set) var favourites = Favourites()

    /// Listening history, newest first. Separate from `lastPlayedChannel`, which keeps a
    /// title and district so the mini player can be populated before the catalogue loads.
    @Published private(set) var recentlyPlayed = RecentlyPlayed()

    /// Where the listener lives, as far as the app is concerned.
    ///
    /// Set by choosing a district, and then applied to every station that broadcasts one —
    /// pick København on P4 and P5 plays København too. A listener has one region; being
    /// asked for it once per station is the thing this removes.
    @Published private(set) var preferredDistrict: District?

    init() {
        loadLastPlayedChannel()
        favourites = Favourites(
            channelIDs: userDefaults.stringArray(forKey: Keys.favouriteChannelIDs) ?? [])
        recentlyPlayed = RecentlyPlayed(
            channelIDs: userDefaults.stringArray(forKey: Keys.recentlyPlayedChannelIDs) ?? [])
        // The name is stored and the id derived, rather than the other way round: an id is
        // not showable, and a name that no longer matches any channel is at least readable.
        preferredDistrict = userDefaults.string(forKey: Keys.preferredDistrictName)
            .map(District.init(name:))
    }

    // MARK: - Favourites

    @discardableResult
    func toggleFavourite(_ channelID: String) -> Bool {
        var updated = favourites
        let isNowFavourite = updated.toggle(channelID)
        favourites = updated
        userDefaults.set(updated.channelIDs, forKey: Keys.favouriteChannelIDs)
        return isNowFavourite
    }

    func isFavourite(_ channelID: String) -> Bool {
        favourites.contains(channelID)
    }

    // MARK: - Region

    /// Remembers the listener's region, or forgets it when passed nil.
    func rememberDistrict(_ district: District?) {
        preferredDistrict = district

        if let district {
            userDefaults.set(district.name, forKey: Keys.preferredDistrictName)
        } else {
            userDefaults.removeObject(forKey: Keys.preferredDistrictName)
        }
    }

    // MARK: - Recently played

    func recordPlay(of channelID: String) {
        var updated = recentlyPlayed
        updated.record(channelID)
        recentlyPlayed = updated
        userDefaults.set(updated.channelIDs, forKey: Keys.recentlyPlayedChannelIDs)
    }
    
    // MARK: - Save Last Played Channel
    func saveLastPlayedChannel(_ channel: DRChannel) {
        recordPlay(of: channel.id)
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