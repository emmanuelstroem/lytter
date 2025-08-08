//
//  DRModels.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import Foundation
import SwiftUI
import Combine

// MARK: - iOS DR Models

// MARK: - API Configuration
struct DRAPIConfig {
    static let baseURL = "https://api.dr.dk/radio/v4"
    static let assetBaseURL = "https://asset.dr.dk/drlyd/images"
    
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
        guard let audioAssets = audioAssets, !audioAssets.isEmpty else {
            // If no audio assets, try to construct a stream URL from the channel
            return constructFallbackStreamURL()
        }
        
        // For live radio, we need to prioritize live streams
        // First try to find a live stream (isStreamLive: true)
        if let liveStream = audioAssets.first(where: { $0.isStreamLive == true }) {
            return liveStream.url
        }
        
        // If no live stream found, check if this is a live radio program
        if isLive {
            // For live programs, use the fallback stream URL instead of on-demand content
            return constructFallbackStreamURL()
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
    
    private func constructFallbackStreamURL() -> String? {
        // Construct a fallback stream URL based on the channel slug
        // This is the standard pattern for DR radio live streams
        let channelSlug = channel.slug.lowercased()
        
        // Map channel slugs to their correct stream URLs
        let streamURLs: [String: String] = [
            "p1": "https://live-icy.gss.dr.dk/AACP1",
            "p2": "https://live-icy.gss.dr.dk/AACP2", 
            "p3": "https://live-icy.gss.dr.dk/AACP3",
            "p4kbh": "https://live-icy.gss.dr.dk/AACP4KBH",
            "p4fyn": "https://live-icy.gss.dr.dk/AACP4FYN",
            "p4sjaelland": "https://live-icy.gss.dr.dk/AACP4SJAEL",
            "p4bornholm": "https://live-icy.gss.dr.dk/AACP4BORNH",
            "p4trekanten": "https://live-icy.gss.dr.dk/AACP4TREK",
            "p4vest": "https://live-icy.gss.dr.dk/AACP4VEST",
            "p4syd": "https://live-icy.gss.dr.dk/AACP4SYD",
            "p4nord": "https://live-icy.gss.dr.dk/AACP4NORD",
            "p4aarhus": "https://live-icy.gss.dr.dk/AACP4AARHUS",
            "p5bornholm": "https://live-icy.gss.dr.dk/AACP5BORNHOLM",
            "p5esbjerg": "https://live-icy.gss.dr.dk/AACP5ESBJERG",
            "p5fyn": "https://live-icy.gss.dr.dk/AACP5FYN",
            "p5kbh": "https://live-icy.gss.dr.dk/AACP5KBH",
            "p5vest": "https://live-icy.gss.dr.dk/AACP5VEST",
            "p5nord": "https://live-icy.gss.dr.dk/AACP5NORD",
            "p5sjaelland": "https://live-icy.gss.dr.dk/AACP5SJAELLAND",
            "p5syd": "https://live-icy.gss.dr.dk/AACP5SYD",
            "p5trekanten": "https://live-icy.gss.dr.dk/AACP5TREKANTEN",
            "p5aarhus": "https://live-icy.gss.dr.dk/AACP5AARHUS",
            "p6beat": "https://live-icy.gss.dr.dk/AACP6BEAT",
            "p8jazz": "https://live-icy.gss.dr.dk/AACP8JAZZ"
        ]
        
        return streamURLs[channelSlug] ?? "https://live-icy.gss.dr.dk/AAC\(channel.slug.uppercased())"
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
        loadChannels()
    }
    
    private func setupBindings() {
        audioPlayer.$isPlaying
            .assign(to: \.isPlaying, on: self)
            .store(in: &cancellables)
        
        audioPlayer.$error
            .assign(to: \.error, on: self)
            .store(in: &cancellables)
    }
    
    private func isCacheValid() -> Bool {
        guard let lastUpdate = lastSchedulesUpdate else { return false }
        return Date().timeIntervalSince(lastUpdate) < cacheValidityDuration
    }
    
    func loadChannels() {
        // Check if we have valid cached data
        if !cachedSchedules.isEmpty && isCacheValid() {
            let channels = Array(Set(cachedSchedules.map { $0.channel })).sorted { $0.title < $1.title }
            self.availableChannels = channels
            return
        }
        
        isLoading = true
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
                    
                    // Restore last played channel if available and recent
                    self.restoreLastPlayedChannel()
                }
                
                // Preload images for all channels
                await self.preloadChannelImages(from: schedules)
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func togglePlayback(for channel: DRChannel) {
        if playingChannel?.id == channel.id {
            if isPlaying {
                audioPlayer.pause()
                // Stop track polling when paused
                stopTrackPolling()
                // Update command center playback state
                audioPlayer.updateCommandCenterPlaybackState()
            } else {
                audioPlayer.resume()
                // Restart track polling when resumed
                Task {
                    await getCurrentTrack(for: channel)
                }
                // Update command center playback state
                audioPlayer.updateCommandCenterPlaybackState()
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
        stopTrackPolling()
        stopProgramRefreshTimer()
        
        // Clear command center info
        audioPlayer.clearCommandCenterInfo()
        
        // Notify observers that playback has stopped
        objectWillChange.send()
    }
    
    func playChannel(_ channel: DRChannel) {
        // If switching to a different channel, stop polling for the previous channel
        if let currentPlayingChannel = playingChannel, currentPlayingChannel.id != channel.id {
            stopTrackPolling()
        }
        
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
        
        // Start track polling for this channel
        Task {
            await self.getCurrentTrack(for: channel)
        }
        
        // Start program refresh timer (check every 5 minutes)
        startProgramRefreshTimer()
        
        // Try to get stream URL from current program first
        var streamURL: String? = currentProgram?.streamURL
        
        // If no stream URL from current program, try to get from any cached program for this channel
        if streamURL == nil {
            let channelPrograms = cachedSchedules.filter { $0.channel.id == channel.id }
            streamURL = channelPrograms.first?.streamURL
        }
        
        // If still no stream URL, construct a fallback URL using the known DR stream pattern
        if streamURL == nil {
            streamURL = "https://live-icy.gss.dr.dk/AAC\(channel.slug.uppercased())"
        }
        
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
    
    func getCachedPrograms(for channel: DRChannel) -> [DREpisode] {
        return cachedSchedules.filter { $0.channel.id == channel.id }
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
            
            // Update current track and schedule next poll
            await MainActor.run {
                self.currentTrack = currentTrack
                self.scheduleNextLivePoll(for: channel, track: currentTrack)
                
                // Update Command Center with new track information
                let currentProgram = self.getCurrentProgram(for: channel)
                self.audioPlayer.updateCommandCenterInfo(channel: channel, program: currentProgram, track: currentTrack)
            }
            
            return currentTrack
        } catch {
            return nil
        }
    }
    
    
    
    private func stopTrackPolling() {
        isPollingForTrack = false
        nextLivePollingTime = nil
    }
    
    private var programRefreshTimer: Timer?
    
    private func startProgramRefreshTimer() {
        // Stop existing timer if any
        stopProgramRefreshTimer()
        
        // Create a timer that fires every 5 minutes
        programRefreshTimer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            self?.refreshCurrentProgram()
        }
    }
    
    private func stopProgramRefreshTimer() {
        programRefreshTimer?.invalidate()
        programRefreshTimer = nil
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
    
    private func scheduleNextLivePoll(for channel: DRChannel, track: DRTrack?) {
        guard let playingChannel = playingChannel, playingChannel.id == channel.id else { return }
        
        let now = Date()
        
        if let track = track, track.isCurrentlyPlaying, let endTime = track.endTime {
            // Track is currently playing - schedule poll when it ends
            nextLivePollingTime = endTime.addingTimeInterval(DRAPIConfig.trackUpdateBuffer)
            
            schedulePoll(at: nextLivePollingTime!, for: channel)
        } else {
            // No currently playing track - use trackPollingInterval
            let nextPollTime = now.addingTimeInterval(DRAPIConfig.trackPollingInterval)
            nextLivePollingTime = nextPollTime
            
            schedulePoll(at: nextPollTime, for: channel)
        }
        
        isPollingForTrack = true
    }
    
    // MARK: - Image Preloading
    
    /// Preloads all images from episodes to improve performance
    /// - Parameter schedules: Array of episodes containing image URLs
    private func preloadChannelImages(from schedules: [DREpisode]) async {
        // Use priority-based preloading for optimal performance
        imageCache.preloadImagesWithPriority(from: schedules)
    }
    
    /// Returns image cache statistics
    func getImageCacheStatistics() -> (memoryCount: Int, diskSize: Int64) {
        return imageCache.getCacheStatistics()
    }
    
    /// Clears all cached images
    func clearImageCache() {
        imageCache.clearAllCaches()
    }
    
    private func schedulePoll(at time: Date, for channel: DRChannel) {
        let delay = time.timeIntervalSinceNow
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            
            // Check if we should still poll (channel still playing)
            guard let playingChannel = self.playingChannel, playingChannel.id == channel.id else { return }
            
            Task { @MainActor in
                await self.getCurrentTrack(for: channel)
            }
        }
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
