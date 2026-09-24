//
//  DRModels.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import Foundation
import SwiftUI
import Combine
import os

// MARK: - iOS DR Models

// MARK: - API Configuration
struct DRAPIConfig {
    /// The DR Radio API version this build targets.
    ///
    /// `api.dr.dk` serves exactly one public version at a time and answers **401** for
    /// every other path under `/radio/` — retired versions and versions that do not exist
    /// alike. So a sudden 401 across the whole app almost always means DR moved on, not
    /// that a key is missing. v4 was retired in favour of v5 this way, and the app simply
    /// stopped working.
    ///
    /// ⚠️ This value is duplicated in `TopShelfExtension/TopShelfNetworkService.swift`,
    /// because the Top Shelf extension is a separate target that cannot see this type.
    /// Change one and you must change the other, or Top Shelf will silently break while
    /// the app keeps working. Sharing it properly needs the extension to stop duplicating
    /// the model layer — tracked in docs/ROADMAP.md.
    static let apiVersion = "v5"

    static let baseURL = "https://api.dr.dk/radio/\(apiVersion)"
    static let assetBaseURL = "https://asset.dr.dk/drlyd/images"

    /// Optional Azure API Management subscription key (Ocp-Apim-Subscription-Key).
    ///
    /// The public API has not required one so far. Before setting this in response to a
    /// 401, check `apiVersion` first — that is the far more likely cause.
    ///
    /// Never commit a real key here: this file is in source control and ships inside the
    /// binary. Read it from a gitignored xcconfig or proxy the API instead.
    static var subscriptionKey: String? = nil

    // API Endpoints
    static let schedulesAllNow = "\(baseURL)/schedules/all/now"
    static let scheduleSnapshot = "\(baseURL)/schedules/snapshot"
    static let indexpointsLive = "\(baseURL)/indexpoints/live"
    
    // Polling Configuration
    static let trackPollingInterval: TimeInterval = 15 // 30 seconds for finished tracks
    static let trackUpdateBuffer: TimeInterval = 5 // 5 seconds buffer before track ends
    
    static func imageURL(for imageAssetURN: String) -> String {
        return "\(assetBaseURL)/\(imageAssetURN)"
    }
}

// MARK: - Channel Models
struct DRChannel: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let slug: String
    let type: String
    let presentationUrl: String?
    
    var displayName: String { title }
    
    // Computed properties for name and district
    var name: String {
        let components = title.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        return components.first.map(String.init) ?? title
    }
    
    var district: String? {
        let components = title.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        return components.count > 1 ? String(components[1]) : nil
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DRChannel, rhs: DRChannel) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Series Models
struct DRSeries: Codable, Equatable {
    let id: String
    let title: String
    let slug: String
    let type: String
    let isAvailableOnDemand: Bool
    let presentationUrl: String?
    let learnId: String
    
    /// Returns the series title with channel name removed to avoid duplication
    /// This is useful when displaying series titles alongside channel names
    func cleanTitle(for channel: DRChannel) -> String {
        return title.replacingOccurrences(of: channel.title, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Audio Asset Models
struct DRAudioAsset: Codable, Equatable {
    let type: String
    let target: String
    let isStreamLive: Bool?
    let format: String
    let bitrate: Int?
    let url: String
}

// MARK: - Image Asset Models
struct DRImageAsset: Codable, Equatable {
    let id: String
    let target: String
    let ratio: String
    let format: String
    let blurHash: String?
    
    var imageURL: String {
        return DRAPIConfig.imageURL(for: id)
    }
}

// MARK: - Role Models (for tracks)
struct DRTrackRole: Codable, Equatable {
    let artistUrn: String
    let role: String
    let name: String
    let musicUrl: String
}

// MARK: - Track Models (for currently playing songs)
struct DRTrack: Identifiable, Codable, Equatable {
    let type: String
    let durationMilliseconds: Int
    let playedTime: String
    let musicUrl: String
    let trackUrn: String
    let classical: Bool
    let roles: [DRTrackRole]?
    let title: String
    let description: String
    
    var id: String { trackUrn }
    
    var playedDate: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: playedTime)
    }
    
    var duration: TimeInterval {
        return TimeInterval(durationMilliseconds / 1000)
    }
    
    var endTime: Date? {
        guard let playedDate = playedDate else { return nil }
        return playedDate.addingTimeInterval(duration)
    }
    
    var isCurrentlyPlaying: Bool {
        guard let playedDate = playedDate else { return false }
        let now = Date()
        let endTime = playedDate.addingTimeInterval(duration)
        return now >= playedDate && now <= endTime
    }
    
    var artistName: String {
        return roles?.first(where: { $0.role == "Hovedkunstner" })?.name ?? description
    }
    
    var displayText: String {
        return "\(artistName): \(title)"
    }
}

// MARK: - Episode/Program Models
struct DREpisode: Identifiable, Codable, Equatable {
    let type: String
    let learnId: String
    let durationMilliseconds: Int
    let categories: [String]?
    let productionNumber: String?
    let startTime: String
    let endTime: String
    let presentationUrl: String?
    let order: Int
    let previousId: String?
    let nextId: String?
    let series: DRSeries?
    let channel: DRChannel
    let audioAssets: [DRAudioAsset]? // Made optional to handle missing audio assets
    let isAvailableOnDemand: Bool
    let hasVideo: Bool?
    let explicitContent: Bool?
    let id: String
    let slug: String
    let title: String
    let description: String? // Made optional based on API analysis
    let imageAssets: [DRImageAsset]? // Made optional to handle missing image assets
    let episodeNumber: Int? // Made optional based on API analysis
    let seasonNumber: Int? // Made optional based on API analysis
    
    var startDate: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: startTime)
    }
    
    var endDate: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: endTime)
    }
    
    var duration: TimeInterval {
        return TimeInterval(durationMilliseconds / 1000)
    }
    
    var isLive: Bool {
        return type == "Live"
    }
    
    var isCurrentlyPlaying: Bool {
        guard let startDate = startDate, let endDate = endDate else { return false }
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    /// Returns the program title with channel name removed to avoid duplication
    /// This is useful when displaying program titles alongside channel names
    func cleanTitle() -> String {
        var cleanTitle = title
        
        // Remove channel slug (case insensitive)
        let channelSlug = channel.slug.lowercased()
        cleanTitle = cleanTitle.replacingOccurrences(of: channelSlug, with: "", options: .caseInsensitive)
        
        // Remove channel title (case insensitive)
        let channelTitle = channel.title.lowercased()
        cleanTitle = cleanTitle.replacingOccurrences(of: channelTitle, with: "", options: .caseInsensitive)
        
        // Clean up any remaining artifacts
        cleanTitle = cleanTitle.replacingOccurrences(of: "  ", with: " ") // Remove double spaces
        cleanTitle = cleanTitle.replacingOccurrences(of: " - ", with: " ") // Remove dash separators
        cleanTitle = cleanTitle.replacingOccurrences(of: " | ", with: " ") // Remove pipe separators
        cleanTitle = cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If we end up with an empty string, return the original title
        return cleanTitle.isEmpty ? title : cleanTitle
    }
    
    var squareImageURL: String? {
        return imageAssets?.first(where: { $0.target == "SquareImage" })?.imageURL
    }
    
    var streamURL: String? {
        guard let audioAssets = audioAssets, !audioAssets.isEmpty else { return nil }
        
        // For live radio, prioritise live streams. v5 returns HLS first, then ICY
        // variants; AVPlayer handles either, and HLS adapts its bitrate.
        if let liveStream = audioAssets.first(where: { $0.isStreamLive == true }) {
            return liveStream.url
        }
        
        // For on-demand content, try to find any stream with target "Stream"
        if let streamAsset = audioAssets.first(where: { $0.target == "Stream" }) {
            return streamAsset.url
        }
        
        // For on-demand content, try to find any stream with target "Progressive"
        if let progressiveAsset = audioAssets.first(where: { $0.target == "Progressive" }) {
            return progressiveAsset.url
        }
        
        // Fallback to first available audio asset
        return audioAssets.first?.url
    }
    
    var primaryImageURL: String? {
        guard let imageAssets = imageAssets, !imageAssets.isEmpty else { return nil }
        
        // Try to find a square or 1:1 ratio image first
        if let squareImage = imageAssets.first(where: { $0.ratio == "1:1" || $0.ratio == "square" }) {
            return squareImage.imageURL
        }
        // Fallback to first available image
        return imageAssets.first?.imageURL
    }
    
    var landscapeImageURL: String? {
        guard let imageAssets = imageAssets, !imageAssets.isEmpty else { return nil }
        
        // Try to find a landscape-oriented image (16:9, 4:3, etc.)
        let landscapeRatios = ["16:9", "4:3", "3:2", "5:3"]
        for ratio in landscapeRatios {
            if let landscapeImage = imageAssets.first(where: { $0.ratio == ratio }) {
                return landscapeImage.imageURL
            }
        }
        
        // If no landscape image found, try to find any non-square image
        if let nonSquareImage = imageAssets.first(where: { $0.ratio != "1:1" && $0.ratio != "square" }) {
            return nonSquareImage.imageURL
        }
        
        // Fallback to primary image
        return primaryImageURL
    }
    
    var categoryIcon: String {
        guard let categories = categories, !categories.isEmpty else {
            return "antenna.radiowaves.left.and.right" // Default radio icon
        }
        
        // Convert categories to lowercase for case-insensitive matching
        let lowercasedCategories = categories.map { $0.lowercased() }
        
        // Check for specific category keywords and return appropriate icons
        if lowercasedCategories.contains(where: { $0.contains("nyheder") || $0.contains("news") || $0.contains("aktualitet") }) {
            return "newspaper" // News and current affairs
        }
        
        if lowercasedCategories.contains(where: { $0.contains("musik") || $0.contains("music") }) {
            if lowercasedCategories.contains(where: { $0.contains("klassisk") || $0.contains("classical") }) {
                return "music.note.list" // Classical music
            }
            if lowercasedCategories.contains(where: { $0.contains("jazz") }) {
                return "music.note.list" // Jazz
            }
            if lowercasedCategories.contains(where: { $0.contains("pop") || $0.contains("rock") }) {
                return "music.mic" // Popular music
            }
            if lowercasedCategories.contains(where: { $0.contains("folk") || $0.contains("folkemusik") }) {
                return "guitars" // Folk music
            }
            return "music.note" // General music
        }
        
        if lowercasedCategories.contains(where: { $0.contains("kultur") || $0.contains("culture") || $0.contains("kunst") || $0.contains("art") }) {
            return "paintbrush" // Culture and arts
        }
        
        if lowercasedCategories.contains(where: { $0.contains("sport") }) {
            return "figure.outdoor.cycle" // Sports
        }
        
        if lowercasedCategories.contains(where: { $0.contains("børn") || $0.contains("children") || $0.contains("kids") }) {
            return "figure.child" // Children's content
        }
        
        if lowercasedCategories.contains(where: { $0.contains("dokumentar") || $0.contains("documentary") }) {
            return "doc.text" // Documentary
        }
        
        if lowercasedCategories.contains(where: { $0.contains("debatt") || $0.contains("debate") || $0.contains("diskussion") }) {
            return "bubble.left.and.bubble.right" // Debate and discussion
        }
        
        if lowercasedCategories.contains(where: { $0.contains("komedie") || $0.contains("comedy") || $0.contains("humor") }) {
            return "face.smiling" // Comedy
        }
        
        if lowercasedCategories.contains(where: { $0.contains("drama") || $0.contains("teater") || $0.contains("theater") }) {
            return "theatermasks" // Drama and theater
        }
        
        if lowercasedCategories.contains(where: { $0.contains("videnskab") || $0.contains("science") || $0.contains("forskning") || $0.contains("research") }) {
            return "atom" // Science and research
        }
        
        if lowercasedCategories.contains(where: { $0.contains("historie") || $0.contains("history") }) {
            return "book.closed" // History
        }
        
        if lowercasedCategories.contains(where: { $0.contains("natur") || $0.contains("nature") || $0.contains("miljø") || $0.contains("environment") }) {
            return "leaf" // Nature and environment
        }
        
        if lowercasedCategories.contains(where: { $0.contains("sundhed") || $0.contains("health") || $0.contains("medicin") || $0.contains("medicine") }) {
            return "heart" // Health and medicine
        }
        
        if lowercasedCategories.contains(where: { $0.contains("økonomi") || $0.contains("economy") || $0.contains("business") || $0.contains("erhverv") }) {
            return "chart.line.uptrend.xyaxis" // Economy and business
        }
        
        if lowercasedCategories.contains(where: { $0.contains("politik") || $0.contains("politics") }) {
            return "building.columns" // Politics
        }
        
        if lowercasedCategories.contains(where: { $0.contains("religion") || $0.contains("tro") || $0.contains("faith") }) {
            return "building.columns.fill" // Religion and faith
        }
        
        if lowercasedCategories.contains(where: { $0.contains("rejse") || $0.contains("travel") || $0.contains("turisme") || $0.contains("tourism") }) {
            return "airplane" // Travel and tourism
        }
        
        if lowercasedCategories.contains(where: { $0.contains("mad") || $0.contains("food") || $0.contains("køkken") || $0.contains("kitchen") }) {
            return "fork.knife" // Food and cooking
        }
        
        if lowercasedCategories.contains(where: { $0.contains("teknologi") || $0.contains("technology") || $0.contains("digital") }) {
            return "laptopcomputer" // Technology
        }
        
        if lowercasedCategories.contains(where: { $0.contains("livsstil") || $0.contains("lifestyle") || $0.contains("mode") || $0.contains("fashion") }) {
            return "person.crop.circle" // Lifestyle and fashion
        }
        
        // Default fallback
        return "antenna.radiowaves.left.and.right"
    }
}

// MARK: - Schedule Response Models
struct DRScheduleResponse: Codable, Equatable {
    let type: String
    let channel: DRChannel
    let items: [DREpisode]
    let scheduleDate: String?
}

// MARK: - Schedule Item for /schedules/all/now endpoint
struct DRScheduleItem: Codable, Equatable {
    let type: String
    let learnId: String? // Make optional since some items don't have it
    let durationMilliseconds: Int
    let categories: [String]?
    let productionNumber: String?
    let startTime: String
    let endTime: String
    let presentationUrl: String?
    let order: Int
    let series: DRSeries?
    let channel: DRChannel
    let audioAssets: [DRAudioAsset]?
    let isAvailableOnDemand: Bool
    let hasVideo: Bool?
    let explicitContent: Bool?
    let title: String? // Some items have this field
    let description: String? // Some items have this field
    let imageAssets: [DRImageAsset]? // Some items have this field
    
    // Convert to DREpisode for compatibility
    func toEpisode() -> DREpisode {
        return DREpisode(
            type: type,
            learnId: learnId ?? "", // Use empty string if learnId is nil
            durationMilliseconds: durationMilliseconds,
            categories: categories,
            productionNumber: productionNumber,
            startTime: startTime,
            endTime: endTime,
            presentationUrl: presentationUrl,
            order: order,
            previousId: nil,
            nextId: nil,
            series: series,
            channel: channel,
            audioAssets: audioAssets,
            isAvailableOnDemand: isAvailableOnDemand,
            hasVideo: hasVideo,
            explicitContent: explicitContent,
            id: learnId ?? "", // Use learnId or empty string
            slug: series?.slug ?? channel.slug,
            title: title ?? series?.title ?? channel.title,
            description: description,
            imageAssets: imageAssets,
            episodeNumber: nil,
            seasonNumber: nil
        )
    }
}

struct DRAllSchedulesResponse: Codable, Equatable {
    let schedules: [DREpisode]
}

// MARK: - Index Points Response Models
struct DRIndexPointsResponse: Codable, Equatable {
    let type: String
    let channel: DRChannel
    let totalSize: Int
    let items: [DRTrack]
    let id: String
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var availableChannels: [DRChannel] = []
    @Published var channelGroups: [ChannelGroup] = []
    @Published var isLoading = false
    @Published var error: String?
}

// MARK: - Channel Organization
struct ChannelGroup: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let channels: [DRChannel]
    let color: String?
    
    var isRegional: Bool {
        return channels.count > 1
    }
    
    var swiftUIColor: Color {
        if let colorString = color {
            return Color(hex: colorString) ?? .blue
        }
        return .blue
    }
}

struct ChannelRegion: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let channel: DRChannel
}

// MARK: - Local Disk Cache
final class DRLocalCache {
    static let shared = DRLocalCache()
    private init() {}

    private let fileName = "dr_schedules_cache.json"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var cacheURL: URL? {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(fileName)
    }

    /// Persist schedules to disk. Call only after a successful API response.
    func save(_ schedules: [DREpisode]) {
        guard let url = cacheURL,
              let data = try? encoder.encode(schedules) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Load schedules from disk. Returns an empty array if nothing is cached yet.
    func load() -> [DREpisode] {
        guard let url = cacheURL,
              let data = try? Data(contentsOf: url),
              let schedules = try? decoder.decode([DREpisode].self, from: data)
        else { return [] }
        return schedules
    }
}

// MARK: - Service Manager
class DRServiceManager: ObservableObject {
    // Direct observable properties
    @Published var availableChannels: [DRChannel] = []
    @Published var channelGroups: [ChannelGroup] = []
    @Published var isLoading = false
    @Published var error: String?
    
    @Published var playingChannel: DRChannel?
    @Published var currentLiveProgram: DREpisode?
    @Published var currentTrack: DRTrack?
    @Published var isPlaying = false
    @Published var playbackError: String? // Separate error for playback issues
    
    let audioPlayer = AudioPlayerService()
    private let networkService = DRNetworkService()
    private let imageCache = ImageCacheService.shared
    let userPreferences = UserPreferencesService()
    private var cancellables = Set<AnyCancellable>()
    
    // Caching properties
    private var cachedSchedules: [DREpisode] = []
    private var lastSchedulesUpdate: Date?
    private let cacheValidityDuration: TimeInterval = 10 * 60 // 10 minutes
    
    // Track polling properties
    private var nextLivePollingTime: Date?
    private var isPollingForTrack = false
    
    init() {
        setupBindings()
        loadDiskCache()   // Populate UI instantly from disk
        loadChannels()    // Refresh from API in background
    }

    /// Synchronously loads the last persisted schedules so the UI is populated
    /// immediately on launch without waiting for the network.
    private func loadDiskCache() {
        let schedules = DRLocalCache.shared.load()
        guard !schedules.isEmpty else { return }
        cachedSchedules = schedules
        availableChannels = Array(Set(schedules.map { $0.channel }))
            .sorted { $0.title < $1.title }
        restoreLastPlayedChannel()
    }
    
    private func setupBindings() {
        audioPlayer.$isPlaying
            .assign(to: \.isPlaying, on: self)
            .store(in: &cancellables)

        // Route audio errors to playbackError, not the general error shown in the channel list
        audioPlayer.$error
            .assign(to: \.playbackError, on: self)
            .store(in: &cancellables)

        // When the remote play command fires but no item is loaded (e.g. restored
        // from cache), delegate back to playChannel so a fresh stream is started.
        audioPlayer.onRequestPlay = { [weak self] in
            guard let self, let channel = self.playingChannel else { return }
            self.playChannel(channel)
        }
    }
    
    private func isCacheValid() -> Bool {
        guard let lastUpdate = lastSchedulesUpdate else { return false }
        return Date().timeIntervalSince(lastUpdate) < cacheValidityDuration
    }
    
    func loadChannels() {
        // In-memory cache still valid — nothing to do
        if !cachedSchedules.isEmpty && isCacheValid() { return }

        // Only show loading spinner when there is no data at all (first launch)
        isLoading = availableChannels.isEmpty
        error = nil

        Task {
            do {
                let schedules = try await networkService.fetchAllSchedules()
                let channels = Array(Set(schedules.map { $0.channel })).sorted { $0.title < $1.title }

                await MainActor.run {
                    self.cachedSchedules = schedules
                    self.lastSchedulesUpdate = Date()
                    self.availableChannels = channels
                    self.isLoading = false
                    self.restoreLastPlayedChannel()
                }

                // Persist to disk only after a confirmed successful response
                DRLocalCache.shared.save(schedules)

                await self.preloadChannelImages(from: schedules)
            } catch {
                await MainActor.run {
                    // Surface the error only when we have no data to show
                    if self.availableChannels.isEmpty {
                        self.error = error.localizedDescription
                    }
                    self.isLoading = false
                }
            }
        }
    }
    
    func togglePlayback(for channel: DRChannel) {
        if playingChannel?.id == channel.id {
            if isPlaying {
                audioPlayer.pause()
                stopPolling()
                audioPlayer.updateCommandCenterPlaybackState()
            } else if audioPlayer.hasLoadedItem {
                // Player item exists — just resume from where it paused
                audioPlayer.resume()
                startPolling(for: channel)
                audioPlayer.updateCommandCenterPlaybackState()
            } else {
                // Channel was restored from cache but never played this session — start fresh
                playChannel(channel)
            }
        } else {
            playChannel(channel)
        }
    }
    
    func stopPlayback() {
        audioPlayer.stop()
        playingChannel = nil
        currentTrack = nil
        currentLiveProgram = nil
        stopPolling()
        
        // Clear command center info
        audioPlayer.clearCommandCenterInfo()
        
        // Notify observers that playback has stopped
        objectWillChange.send()
    }
    
    func playChannel(_ channel: DRChannel) {
        // Switching channels: drop the previous channel's polling before starting the
        // new one, so two loops never run at once.
        stopPolling()
        
        // Get current program from cached schedules
        let currentProgram = getCurrentProgram(for: channel)
        
        // Update UI on main actor
        Task { @MainActor in
            self.currentLiveProgram = currentProgram
            self.currentTrack = nil
            
            // Update Command Center with new program information
            if let playingChannel = self.playingChannel {
                self.audioPlayer.updateCommandCenterInfo(channel: playingChannel, program: currentProgram, track: self.currentTrack)
            }
        }
        
        // Poll the live track and refresh the programme for as long as this channel plays.
        startPolling(for: channel)
        
        // Try to get stream URL from current program first
        var streamURL: String? = currentProgram?.streamURL
        
        // If no stream URL from current program, try to get from any cached program for this channel
        if streamURL == nil {
            let channelPrograms = cachedSchedules.filter { $0.channel.id == channel.id }
            streamURL = channelPrograms.first?.streamURL
        }
        
        // There is deliberately no hardcoded fallback here. The previous one guessed
        // https://live-icy.gss.dr.dk/AAC<SLUG>, and every URL in that family now returns
        // 404 — so it turned "we have no stream" into a stream that fails obscurely once
        // playback had already started. Failing here gives the user an honest message.

        // Play the stream
        if let finalStreamURL = streamURL,
           let url = URL(string: finalStreamURL) {
            Task { @MainActor in
                self.playingChannel = channel
                self.audioPlayer.play(url: url)
                
                // Save the last played channel
                self.userPreferences.saveLastPlayedChannel(channel)
                
                // Update Command Center with channel and program info
                let currentProgram = self.getCurrentProgram(for: channel)
                self.audioPlayer.updateCommandCenterInfo(channel: channel, program: currentProgram, track: self.currentTrack)
            }
        } else {
            Task { @MainActor in
                self.playbackError = "No stream URL available for \(channel.title)"
            }
        }
    }
    
    func getCurrentProgram(for channel: DRChannel) -> DREpisode? {
        let channelPrograms = cachedSchedules.filter { $0.channel.id == channel.id }
        return channelPrograms.first { $0.isCurrentlyPlaying } ?? channelPrograms.first
    }
    
    /// Today's full schedule for a channel.
    ///
    /// `/schedules/all/now` only carries what is on air right now, so the rest of the
    /// day comes from the snapshot endpoint — which `DRNetworkService` has always
    /// implemented and nothing has ever called.
    func loadSchedule(for channel: DRChannel) async -> [DREpisode] {
        do {
            return try await networkService.fetchScheduleSnapshot(for: channel.slug).items
        } catch {
            Log.network.error(
                "schedule snapshot failed for \(channel.slug, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
    
    func getCachedPrograms(for channel: DRChannel) -> [DREpisode] {
        return cachedSchedules.filter { $0.channel.id == channel.id }
    }

    // MARK: - Deep Link Resolution

    /// Resolves the identifier carried by a deep link to a real channel.
    ///
    /// Two link formats exist and they do not agree on what identifies a channel:
    ///
    ///   - `DeepLinkHandler.generateDeepLinkURL` emits `lyt:///channel/<id>`, where id is
    ///     an opaque URN such as `urn:dr:radio:channel:5fa156d1da351264f87b462d`.
    ///   - The Top Shelf extension emits `lytter://radio/channel/<slug>`, where slug is
    ///     the short form such as `p1`.
    ///
    /// Callers previously matched on `id` only, so every Top Shelf play action silently
    /// did nothing. Accepting either form fixes that without changing the URLs already
    /// baked into the Top Shelf items the system may have cached.
    func channel(forDeepLinkIdentifier identifier: String) -> DRChannel? {
        if let byId = availableChannels.first(where: { $0.id == identifier }) {
            return byId
        }
        return availableChannels.first {
            $0.slug.caseInsensitiveCompare(identifier) == .orderedSame
        }
    }

    // MARK: - Last Played Channel Management
    
    private func restoreLastPlayedChannel() {
        // Only restore if we have available channels and no current playback
        guard !availableChannels.isEmpty && playingChannel == nil else { return }
        
        // Find the last played channel in available channels
        if let lastPlayedChannel = userPreferences.findLastPlayedChannel(in: availableChannels) {
            // Only restore if it was played recently (within 24 hours)
            if userPreferences.isLastPlayedRecent(within: 24) {
                // Set the playing channel but don't start playback automatically
                // This will populate the mini player with the last played channel
                playingChannel = lastPlayedChannel
                
                // Get current program for the restored channel
                currentLiveProgram = getCurrentProgram(for: lastPlayedChannel)
                
                // Update Command Center with restored channel info
                audioPlayer.updateCommandCenterInfo(channel: lastPlayedChannel, program: currentLiveProgram, track: currentTrack)
            }
        }
    }
    
    func findLastPlayedChannel(in channels: [DRChannel]) -> DRChannel? {
        return userPreferences.findLastPlayedChannel(in: channels)
    }
    
    func getCurrentTrack(for channel: DRChannel) async -> DRTrack? {
        do {
            let indexPoints = try await networkService.fetchIndexPoints(for: channel.slug)
            let currentTrack = indexPoints.items.first { $0.isCurrentlyPlaying }
            
            await MainActor.run {
                self.currentTrack = currentTrack
                
                // Update Command Center with new track information
                let currentProgram = self.getCurrentProgram(for: channel)
                self.audioPlayer.updateCommandCenterInfo(channel: channel, program: currentProgram, track: currentTrack)
            }
            
            return currentTrack
        } catch {
            return nil
        }
    }
    
    
    
    private var trackPollingTask: Task<Void, Never>?
    private var programRefreshTask: Task<Void, Never>?
    private let programRefreshInterval: TimeInterval = 5 * 60
    
    /// Polls the live track for as long as `channel` is actually playing.
    ///
    /// This replaced a self-perpetuating chain — getCurrentTrack scheduled the next poll
    /// via DispatchQueue.asyncAfter, which called getCurrentTrack again. Nothing held a
    /// handle to the pending work, and its only guard was that `playingChannel` still
    /// matched. Since pausing leaves `playingChannel` set so the mini player keeps its
    /// content, pausing did not stop the chain: the app went on hitting
    /// /indexpoints/live every ~15s, foreground or background, until the channel changed
    /// or the app was killed.
    private func startPolling(for channel: DRChannel) {
        stopPolling()
        isPollingForTrack = true
        
        trackPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let track = await self.getCurrentTrack(for: channel)
                guard !Task.isCancelled else { return }
                
                // Wake just after the current track ends, otherwise fall back to the
                // fixed interval.
                let delay: TimeInterval
                if let track, track.isCurrentlyPlaying, let endTime = track.endTime {
                    delay = max(endTime.timeIntervalSinceNow + DRAPIConfig.trackUpdateBuffer, 1)
                } else {
                    delay = DRAPIConfig.trackPollingInterval
                }
                await MainActor.run {
                    self.nextLivePollingTime = Date().addingTimeInterval(delay)
                }
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        programRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self?.programRefreshInterval ?? 300) * 1_000_000_000)
                guard !Task.isCancelled, let self else { return }
                await MainActor.run { self.refreshCurrentProgram() }
            }
        }
    }
    
    /// Stops both loops. Cancellation is real now: `Task.sleep` throws on cancel and the
    /// loops check `Task.isCancelled`, so nothing is left in flight.
    private func stopPolling() {
        trackPollingTask?.cancel()
        trackPollingTask = nil
        programRefreshTask?.cancel()
        programRefreshTask = nil
        isPollingForTrack = false
        nextLivePollingTime = nil
    }
    
    
    
    func clearPlaybackError() {
        playbackError = nil
    }
    
    // MARK: - Program Refresh
    
    func refreshCurrentProgram() {
        guard let playingChannel = playingChannel else { return }
        
        let newProgram = getCurrentProgram(for: playingChannel)
        
        // Only update if the program has changed
        if newProgram?.id != currentLiveProgram?.id {
            Task { @MainActor in
                self.currentLiveProgram = newProgram
                
                // Update Command Center with new program information
                self.audioPlayer.updateCommandCenterInfo(channel: playingChannel, program: newProgram, track: self.currentTrack)
            }
        }
    }
    
    // MARK: - New Live Polling System
    
    // MARK: - Image Preloading
    
    /// Warms the artwork the channel lists show. Only the primary image per episode, at
    /// thumbnail size, four downloads at a time — see `preloadPrimaryImages`.
    private func preloadChannelImages(from schedules: [DREpisode]) async {
        imageCache.preloadPrimaryImages(from: schedules)
    }
    
    /// Returns image cache statistics
    func getImageCacheStatistics() -> (memoryCount: Int, diskSize: Int64) {
        return imageCache.getCacheStatistics()
    }
    
    /// Clears all cached images
    func clearImageCache() {
        imageCache.clearAllCaches()
    }
}

// MARK: - Array Extension
extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        return Array(Set(self))
    }
}

// MARK: - Image Asset Extensions
extension DREpisode {
    /// Returns all image URLs from this episode
    var allImageURLs: [String] {
        guard let imageAssets = imageAssets else { return [] }
        return imageAssets.map { $0.imageURL }
    }
}

// MARK: - Selection State
class SelectionState: ObservableObject {
    @Published var selectedChannel: DRChannel?
    @Published var selectedRegion: ChannelRegion?
    
    func selectChannel(_ channel: DRChannel, showSheet: Bool = false) {
        selectedChannel = channel
        selectedRegion = nil
    }
    
    func openNestedNavigation(for channel: DRChannel, in region: ChannelRegion) {
        selectedChannel = channel
        selectedRegion = region
    }
}

// MARK: - Navigation State
class ChannelNavigationState: ObservableObject {
    @Published var navigationPath: [String] = []
    
    func navigateToChannel(_ channelId: String) {
        navigationPath.append(channelId)
    }
    
    func navigateBack() {
        _ = navigationPath.popLast()
    }
}

// MARK: - Channel Organizer
struct ChannelOrganizer {
    static func getRegionsForGroup(_ channels: [DRChannel], groupPrefix: String) -> [ChannelRegion] {
        return channels.map { channel in
            let regionName = channel.displayName.replacingOccurrences(of: groupPrefix, with: "").trimmingCharacters(in: .whitespaces)
            return ChannelRegion(id: channel.id, name: regionName, channel: channel)
        }
    }
}



// MARK: - Color Extension
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
            case 3: // RGB (12-bit)
                (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
            case 6: // RGB (24-bit)
                (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
            case 8: // ARGB (32-bit)
                (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
            default:
                return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 
