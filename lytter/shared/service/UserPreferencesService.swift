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
        static let showsArtwork = "showsArtwork"
        static let screenOffDelaySeconds = "screenOffDelaySeconds"
        static let recentSearchChannelIDs = "recentSearchChannelIDs"
        static let favouriteShows = "favouriteShows"
    }
    
    // MARK: - Published Properties
    @Published var lastPlayedChannel: DRChannel?
    @Published var lastPlayedTimestamp: Date?

    /// Pinned channels. Only ids are stored: a channel's title and artwork come from the
    /// catalogue, and persisting a copy would leave stale names on screen after DR renames
    /// something.
    @Published private(set) var favourites = Favourites()

    /// Pinned programmes (F33). Unlike channels, each keeps its title and artwork: a show is
    /// in the catalogue only while it is on air. Stored as JSON.
    @Published private(set) var favouriteShows = FavouriteShows()

    /// Listening history, newest first. Separate from `lastPlayedChannel`, which keeps a
    /// title and district so the mini player can be populated before the catalogue loads.
    @Published private(set) var recentlyPlayed = RecentlyPlayed()

    /// Where the listener lives, as far as the app is concerned.
    ///
    /// Set by choosing a district, and then applied to every station that broadcasts one —
    /// pick København on P4 and P5 plays København too. A listener has one region; being
    /// asked for it once per station is the thing this removes.
    @Published private(set) var preferredDistrict: District?

    /// Whether programme artwork is shown (F43). Off, every picture is replaced by the
    /// station's colour and name, and the catalogue's images are not preloaded.
    @Published private(set) var showsArtwork = true

    /// How long the app waits, while playing, before blacking out the screen (F43).
    @Published private(set) var screenOffDelay = ScreenOffDelay.default

    /// Stations chosen from a search, newest first — what Search lists before anything has
    /// been typed. Ids only, for the same reason as `recentlyPlayed`, whose type it borrows:
    /// both are a short recency list with no duplicates.
    @Published private(set) var recentSearches = RecentlyPlayed()

    init() {
        loadLastPlayedChannel()
        favourites = Favourites(
            channelIDs: userDefaults.stringArray(forKey: Keys.favouriteChannelIDs) ?? [])
        recentlyPlayed = RecentlyPlayed(
            channelIDs: userDefaults.stringArray(forKey: Keys.recentlyPlayedChannelIDs) ?? [])
        // The name is stored and the id derived, rather than the other way round: an id is
        // not showable, and a name that no longer matches any channel is at least readable.
        // An empty name is no region: it reads as one, with nothing to show and something
        // to forget.
        preferredDistrict = userDefaults.string(forKey: Keys.preferredDistrictName)
            .flatMap { $0.isEmpty ? nil : District(name: $0) }
        // bool(forKey:) and integer(forKey:) rather than a cast: they also read the strings
        // a launch argument stores ("-showsArtwork NO"), which `as? Bool` does not.
        showsArtwork = userDefaults.object(forKey: Keys.showsArtwork) == nil
            || userDefaults.bool(forKey: Keys.showsArtwork)
        screenOffDelay = userDefaults.object(forKey: Keys.screenOffDelaySeconds) == nil
            ? Self.defaultScreenOffDelay
            : ScreenOffDelay(rawValue: userDefaults.integer(forKey: Keys.screenOffDelaySeconds))
                ?? Self.defaultScreenOffDelay
        recentSearches = RecentlyPlayed(
            channelIDs: userDefaults.stringArray(forKey: Keys.recentSearchChannelIDs) ?? [])
        favouriteShows = Self.loadFavouriteShows(from: userDefaults)
    }

    private static func loadFavouriteShows(from defaults: UserDefaults) -> FavouriteShows {
        #if DEBUG
        if let fixtures = UITestFixtures.favouriteShows { return FavouriteShows(shows: fixtures) }
        #endif
        guard let data = defaults.data(forKey: Keys.favouriteShows),
              let shows = try? JSONDecoder().decode([FavouriteShow].self, from: data) else {
            return FavouriteShows()
        }
        return FavouriteShows(shows: shows)
    }

    /// The delay before anything has been chosen. Never, under UI tests: a test that sits
    /// still for half a minute while something plays would otherwise find a black screen.
    /// A test of the blackout itself sets one with `-screenOffDelaySeconds`.
    private static var defaultScreenOffDelay: ScreenOffDelay {
        #if DEBUG
        if UITestFixtures.isActive { return .never }
        #endif
        return .default
    }

    // MARK: - Settings

    func setShowsArtwork(_ shows: Bool) {
        showsArtwork = shows
        userDefaults.set(shows, forKey: Keys.showsArtwork)
    }

    func setScreenOffDelay(_ delay: ScreenOffDelay) {
        screenOffDelay = delay
        userDefaults.set(delay.rawValue, forKey: Keys.screenOffDelaySeconds)
    }

    /// Unpins every channel. Settings asks first; this does not.
    func removeAllFavourites() {
        favourites = Favourites()
        userDefaults.removeObject(forKey: Keys.favouriteChannelIDs)
    }

    /// Forgets the listening history. `lastPlayedChannel` stays: it is what the mini player
    /// shows at launch, not a list anyone reads.
    func clearRecentlyPlayed() {
        recentlyPlayed = RecentlyPlayed()
        userDefaults.removeObject(forKey: Keys.recentlyPlayedChannelIDs)
    }

    // MARK: - Recent searches

    func recordSearch(of channelID: String) {
        var updated = recentSearches
        updated.record(channelID)
        recentSearches = updated
        userDefaults.set(updated.channelIDs, forKey: Keys.recentSearchChannelIDs)
    }

    func clearRecentSearches() {
        recentSearches = RecentlyPlayed()
        userDefaults.removeObject(forKey: Keys.recentSearchChannelIDs)
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

    // MARK: - Favourite shows

    @discardableResult
    func toggleFavouriteShow(_ show: FavouriteShow) -> Bool {
        var updated = favouriteShows
        let isNowFavourite = updated.toggle(show)
        setFavouriteShows(updated)
        return isNowFavourite
    }

    func removeFavouriteShow(_ seriesID: String) {
        var updated = favouriteShows
        updated.remove(seriesID)
        setFavouriteShows(updated)
    }

    func isFavouriteShow(_ seriesID: String) -> Bool {
        favouriteShows.contains(seriesID)
    }

    /// Unpins every show. Settings asks first; this does not.
    func removeAllFavouriteShows() {
        favouriteShows = FavouriteShows()
        userDefaults.removeObject(forKey: Keys.favouriteShows)
    }

    /// Brings pinned shows up to date with a schedule just fetched: a new title, new
    /// artwork, another channel. Writes only if something changed.
    func updateFavouriteShows(from episodes: [DREpisode]) {
        var updated = favouriteShows
        var changed = false
        for episode in episodes where updated.update(from: episode) { changed = true }
        if changed { setFavouriteShows(updated) }
    }

    private func setFavouriteShows(_ shows: FavouriteShows) {
        favouriteShows = shows
        #if DEBUG
        // Fixture shows are the test's, not the simulator's.
        if UITestFixtures.favouriteShows != nil { return }
        #endif
        if let data = try? JSONEncoder().encode(shows.shows) {
            userDefaults.set(data, forKey: Keys.favouriteShows)
        }
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