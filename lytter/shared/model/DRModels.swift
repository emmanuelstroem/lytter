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
#if os(tvOS)
import TVServices
#endif

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
    nonisolated static let apiVersion = "v5"

    nonisolated static let baseURL = "https://api.dr.dk/radio/\(apiVersion)"
    nonisolated static let assetBaseURL = "https://asset.dr.dk/drlyd/images"

    /// Optional Azure API Management subscription key (Ocp-Apim-Subscription-Key).
    ///
    /// The public API has not required one so far. Before setting this in response to a
    /// 401, check `apiVersion` first — that is the far more likely cause.
    ///
    /// Never commit a real key here: this file is in source control and ships inside the
    /// binary. Read it from a gitignored xcconfig or proxy the API instead.
    /// Supplied by the build, never assigned at runtime — which is why it is a `let`.
    /// A mutable global is shared mutable state and rejected outright under Swift 6, and
    /// nothing ever wrote to this one.
    nonisolated static let subscriptionKey: String? =
        Bundle.main.object(forInfoDictionaryKey: "DRSubscriptionKey") as? String

    // API Endpoints
    nonisolated static let schedulesAllNow = "\(baseURL)/schedules/all/now"
    nonisolated static let scheduleSnapshot = "\(baseURL)/schedules/snapshot"
    nonisolated static let indexpointsLive = "\(baseURL)/indexpoints/live"
    /// Every station, with its districts listed under it. The only endpoint that says
    /// which channels are districts, and of what.
    nonisolated static let channelDirectory = "\(baseURL)/channels"
    
    // Polling Configuration
    nonisolated static let trackPollingInterval: TimeInterval = 15 // 30 seconds for finished tracks
    nonisolated static let trackUpdateBuffer: TimeInterval = 5 // 5 seconds buffer before track ends
    
    nonisolated static func imageURL(for imageAssetURN: String) -> String {
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

    // What DR's channel directory says this channel is. The schedule endpoint the app
    // lists channels from sends none of it, so these stay nil until a `ChannelDirectory`
    // has been applied, and are then carried through the disk cache with the channel.

    /// The station this channel belongs to: "p4" for P4 København, the channel's own slug
    /// for a national channel such as P1.
    var stationSlug: String? = nil

    /// The station's own title: "P4" for P4 København.
    var stationTitle: String? = nil

    /// DR's name for the district, for a channel that is one.
    var districtName: String? = nil

    var displayName: String { title }

    /// The station's name: "P4" for P4 København, "P1" for P1.
    ///
    /// Taken from DR's directory where it has been applied. Otherwise read from the title,
    /// which is the fallback and nothing more: it splits on the first space, so a national
    /// channel with a two-word title — DR's directory has one, "P7 MIX" — would be read as
    /// station "P7" with a district called "MIX".
    var name: String {
        stationTitle ?? titleParts.station
    }

    /// The district, for a channel that is one.
    ///
    /// Once the directory has been applied, only what DR calls a district is one. Before
    /// that, whatever follows the first space in the title.
    var district: String? {
        stationSlug != nil ? districtName : titleParts.district
    }

    /// What identifies the station when channels are grouped into stations.
    ///
    /// DR's own station slug where the directory has been applied. Otherwise the name read
    /// from the title, lowercased so that a channel the directory does not list still
    /// lands beside its siblings rather than in a group of its own.
    var stationKey: String {
        stationSlug ?? name.lowercased()
    }

    private var titleParts: (station: String, district: String?) {
        let components = title.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        let station = components.first.map(String.init) ?? title
        return (station, components.count > 1 ? String(components[1]) : nil)
    }

    /// The name including the district, where there is one: "P4 - København".
    ///
    /// Needed wherever a card stands for one particular channel rather than for a station.
    /// A pinned favourite is a specific district, and "P4" alone does not say which of the
    /// ten it is — all ten would caption themselves identically.
    ///
    /// Not localised: a separator, not a phrase.
    var qualifiedName: String {
        guard let district else { return name }
        return "\(name) - \(district)"
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
/// DR's timestamps, such as "2026-10-02T20:49:10+00:00".
///
/// One formatter for the app. `startDate`, `endDate` and `playedDate` each built a new one
/// on every access, and they are read inside filters over whole arrays: picking the track
/// being heard runs every second while paused behind live, across the full track list.
enum DRDate {
    /// `ISO8601DateFormatter` is documented as thread-safe, so one instance can be shared
    /// across isolation domains; Swift cannot see that, hence `nonisolated(unsafe)`.
    nonisolated(unsafe) private static let formatter = ISO8601DateFormatter()

    nonisolated static func parse(_ string: String) -> Date? {
        formatter.date(from: string)
    }
}

/// One of DR's timestamps, parsed once when it is made or decoded.
///
/// The parsed dates are read from view bodies and per-second checks — whether a programme
/// is on air, which track is being heard — and parsing took ~25 µs each time, which was
/// most of what a programme lookup cost. Encodes as the bare string DR sent, so the disk
/// cache keeps its format.
struct DRTimestamp: Codable, Equatable {
    let string: String
    let date: Date?

    init(_ string: String) {
        self.string = string
        self.date = DRDate.parse(string)
    }

    init(from decoder: Decoder) throws {
        self.init(try decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }

    /// The date follows from the string.
    static func == (lhs: DRTimestamp, rhs: DRTimestamp) -> Bool { lhs.string == rhs.string }
}

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
    private let played: DRTimestamp
    let musicUrl: String
    let trackUrn: String
    let classical: Bool
    let roles: [DRTrackRole]?
    let title: String
    let description: String
    
    private enum CodingKeys: String, CodingKey {
        case type, durationMilliseconds, played = "playedTime", musicUrl, trackUrn, classical,
             roles, title, description
    }

    init(type: String, durationMilliseconds: Int, playedTime: String, musicUrl: String,
         trackUrn: String, classical: Bool, roles: [DRTrackRole]?, title: String,
         description: String) {
        self.type = type
        self.durationMilliseconds = durationMilliseconds
        self.played = DRTimestamp(playedTime)
        self.musicUrl = musicUrl
        self.trackUrn = trackUrn
        self.classical = classical
        self.roles = roles
        self.title = title
        self.description = description
    }

    var id: String { trackUrn }

    var playedTime: String { played.string }
    var playedDate: Date? { played.date }
    
    var duration: TimeInterval {
        return TimeInterval(durationMilliseconds / 1000)
    }
    
    var endTime: Date? {
        guard let playedDate = playedDate else { return nil }
        return playedDate.addingTimeInterval(duration)
    }
    
    var isCurrentlyPlaying: Bool { isPlaying(at: Date()) }

    /// Whether this track was on air at `date`. Behind live, what is heard is not what is
    /// on air, so the player asks about the moment being listened to.
    func isPlaying(at date: Date) -> Bool {
        guard let playedDate = playedDate else { return false }
        return date >= playedDate && date <= playedDate.addingTimeInterval(duration)
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
    private let start: DRTimestamp
    private let end: DRTimestamp
    let presentationUrl: String?
    let order: Int
    let previousId: String?
    let nextId: String?
    let series: DRSeries?
    /// A `var` so the channel directory can be applied to it after decoding.
    var channel: DRChannel
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

    private enum CodingKeys: String, CodingKey {
        case type, learnId, durationMilliseconds, categories, productionNumber,
             start = "startTime", end = "endTime", presentationUrl, order, previousId, nextId,
             series, channel, audioAssets, isAvailableOnDemand, hasVideo, explicitContent, id,
             slug, title, description, imageAssets, episodeNumber, seasonNumber
    }

    init(type: String, learnId: String, durationMilliseconds: Int, categories: [String]?,
         productionNumber: String?, startTime: String, endTime: String,
         presentationUrl: String?, order: Int, previousId: String?, nextId: String?,
         series: DRSeries?, channel: DRChannel, audioAssets: [DRAudioAsset]?,
         isAvailableOnDemand: Bool, hasVideo: Bool?, explicitContent: Bool?, id: String,
         slug: String, title: String, description: String?, imageAssets: [DRImageAsset]?,
         episodeNumber: Int?, seasonNumber: Int?) {
        self.type = type
        self.learnId = learnId
        self.durationMilliseconds = durationMilliseconds
        self.categories = categories
        self.productionNumber = productionNumber
        self.start = DRTimestamp(startTime)
        self.end = DRTimestamp(endTime)
        self.presentationUrl = presentationUrl
        self.order = order
        self.previousId = previousId
        self.nextId = nextId
        self.series = series
        self.channel = channel
        self.audioAssets = audioAssets
        self.isAvailableOnDemand = isAvailableOnDemand
        self.hasVideo = hasVideo
        self.explicitContent = explicitContent
        self.id = id
        self.slug = slug
        self.title = title
        self.description = description
        self.imageAssets = imageAssets
        self.episodeNumber = episodeNumber
        self.seasonNumber = seasonNumber
    }

    /// Identifies this *broadcast*, as opposed to the episode being broadcast.
    ///
    /// `id` is an episode URN, and a channel airs the same episode more than once a day:
    /// P1 ran `…:episode:6a01c544` at 10:15, 16:05 and again at 17:03 on 2026-09-24, all
    /// three carrying that one id. A `ForEach` keyed on `id` therefore sees duplicate
    /// identities and renders the *first* matching row for each repeat — three rows with
    /// the same title, the same time, and the same "On air" badge.
    ///
    /// A channel cannot air two things at once, so the channel and start time together
    /// name one broadcast.
    var broadcastID: String { "\(channel.id)|\(startTime)" }

    /// The programme's name, without the episode description.
    ///
    /// `title` carries both — "Prompt: AI sladrer og Apple bliver boomere" — which is too
    /// long to read on a card. DR supplies the name separately as the series title
    /// ("Prompt"), so this is a lookup rather than a guess about colons. Falls back to the
    /// cleaned title for the occasional entry with no series.
    var programmeName: String {
        if let series = series?.title, !series.isEmpty { return series }
        return cleanTitle()
    }

    /// How far through this broadcast `date` falls, from 0 to 1.
    ///
    /// `nil` when the schedule does not give both ends, or gives a zero-length slot —
    /// callers show no progress at all rather than an empty bar.
    func progress(at date: Date) -> Double? {
        guard let start = startDate, let end = endDate else { return nil }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return nil }
        return min(max(date.timeIntervalSince(start) / total, 0), 1)
    }

    /// Whole minutes left of this broadcast at `date`, never negative.
    func minutesRemaining(at date: Date) -> Int? {
        guard let end = endDate else { return nil }
        return max(Int(end.timeIntervalSince(date) / 60), 0)
    }

    var startTime: String { start.string }
    var endTime: String { end.string }
    var startDate: Date? { start.date }
    var endDate: Date? { end.date }
    
    var duration: TimeInterval {
        return TimeInterval(durationMilliseconds / 1000)
    }
    
    var isLive: Bool {
        return type == "Live"
    }
    
    var isCurrentlyPlaying: Bool { isPlaying(at: Date()) }

    func isPlaying(at date: Date) -> Bool {
        guard let startDate = startDate, let endDate = endDate else { return false }
        return date >= startDate && date <= endDate
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

// MARK: - Local Disk Cache

/// The last catalogue DR returned, on disk, so a launch has something to show before the
/// network answers — or when it never does (F42).
///
/// Two things made it unsafe to lean on (P13). It had no version, so a change to `DREpisode`
/// that the old file could not decode emptied it without a word: the next offline launch
/// showed "You're offline" with nothing behind it, as if nothing had ever been cached. And it
/// had no age, so a snapshot from last week was loaded as readily as one from a minute ago.
///
/// On tvOS it lives in the app group's container, where the Top Shelf extension reads it
/// rather than fetching the schedule itself (P14). That makes its format a contract with
/// `TopShelfSharedCache`, which decodes the parts it needs: `version`, `savedAt`, and each
/// schedule's `channel`, `title` and `imageAssets`.
final class DRLocalCache {
    static let shared = DRLocalCache()

    /// Bump when `DREpisode` changes in a way an older file cannot decode. A file written
    /// under another version is discarded, and says so in the log.
    static let schemaVersion = 1

    /// Older than this, a snapshot is not loaded at all. Its programmes are long over and
    /// DR's line-up may have moved on; the channel list it would give is not worth showing.
    static let maxAge: TimeInterval = 7 * 24 * 60 * 60

    /// What is written: the schedules, and when and under which version they were saved.
    struct Snapshot: Codable {
        let version: Int
        let savedAt: Date
        let schedules: [DREpisode]
    }

    private let fileURL: URL?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Shared with the Top Shelf extension, which declares the same group and file name.
    static let appGroup = "group.com.eopio.lytter"
    static let fileName = "dr_schedules_cache.json"

    private convenience init() {
        let ownCaches = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(Self.fileName)
        #if os(tvOS)
        let shared = Self.sharedFileURL()
        if let shared, let ownCaches { Self.move(ownCaches, to: shared) }
        self.init(fileURL: shared ?? ownCaches)
        #else
        self.init(fileURL: ownCaches)
        #endif
    }

    /// For tests, which point it at a file of their own.
    init(fileURL: URL?) {
        self.fileURL = fileURL
    }

    #if os(tvOS)
    /// The group container's `Library/Caches`: on tvOS only caches may be written, and the
    /// system may purge them, which costs no more than a fetch. Nil if the group is not in
    /// the entitlements, and the cache then stays in the app's own caches as before.
    private static func sharedFileURL() -> URL? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            Log.network.warning("app group unavailable; Top Shelf will fetch for itself")
            return nil
        }
        let caches = container.appendingPathComponent("Library/Caches", isDirectory: true)
        try? FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        return caches.appendingPathComponent(fileName)
    }

    /// Brings the file an earlier version saved in the app's own caches across, once, so
    /// the update does not cost the offline launch its cache.
    private static func move(_ legacy: URL, to shared: URL) {
        let files = FileManager.default
        guard files.fileExists(atPath: legacy.path) else { return }
        if files.fileExists(atPath: shared.path) {
            try? files.removeItem(at: legacy)
        } else {
            try? files.moveItem(at: legacy, to: shared)
        }
    }
    #endif

    /// Persist schedules to disk. Call only after a successful API response.
    func save(_ schedules: [DREpisode], at date: Date = Date()) {
        let snapshot = Snapshot(version: Self.schemaVersion, savedAt: date, schedules: schedules)
        guard let url = fileURL, let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
        #if os(tvOS)
        // The Top Shelf is drawn from this file now, so ask the system to draw it again.
        TVTopShelfContentProvider.topShelfContentDidChange()
        #endif
    }

    /// The cached schedules, or an empty array if there are none worth using.
    func load(now: Date = Date()) -> [DREpisode] {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return [] }
        guard let snapshot = decode(data, writtenAt: modificationDate(of: url)) else {
            Log.network.warning("discarding a disk cache that does not decode as this version")
            return []
        }
        guard snapshot.version == Self.schemaVersion else {
            Log.network.warning(
                "discarding a disk cache from schema version \(snapshot.version, privacy: .public)")
            return []
        }
        guard now.timeIntervalSince(snapshot.savedAt) <= Self.maxAge else {
            Log.network.info("discarding a disk cache older than its maximum age")
            return []
        }
        return snapshot.schedules
    }

    /// The current format, or the bare array written before it had a version. That one is
    /// read as version 1 — the same `DREpisode` — so an update does not throw away the cache
    /// every existing install has, and dated by the file, which is when it was saved.
    private func decode(_ data: Data, writtenAt fileDate: Date?) -> Snapshot? {
        if let snapshot = try? decoder.decode(Snapshot.self, from: data) { return snapshot }
        guard let legacy = try? decoder.decode([DREpisode].self, from: data) else { return nil }
        return Snapshot(version: 1, savedAt: fileDate ?? .distantPast, schedules: legacy)
    }

    private func modificationDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}

// MARK: - Service Manager
class DRServiceManager: ObservableObject {
    /// The app's one manager.
    ///
    /// Static rather than created by the scene, because an App Intent (F15) can start the
    /// app with no scene at all — Siri, the Action Button or a Shortcuts automation
    /// launching it in the background to play a station. lytterApp hands this same
    /// instance to every screen, so what the intent starts is what the screens show.
    static let shared = DRServiceManager()

    // Direct observable properties
    @Published var availableChannels: [DRChannel] = []
    @Published var isLoading = false
    /// Why the last catalogue fetch failed, or nil once one succeeds. Views read
    /// `connectionProblem`, not this.
    @Published private(set) var catalogueFailure: RequestFailure?
    /// Whether the device has a route to the internet. Assumed until `NetworkMonitor` says.
    @Published private(set) var isOnline = true
    /// True once a fetch with nothing on screen has run past `ConnectionTiming.slowAfter`.
    @Published private(set) var isWaitingLong = false
    
    @Published var playingChannel: DRChannel?
    @Published var currentLiveProgram: DREpisode?
    @Published var currentTrack: DRTrack?
    @Published var isPlaying = false
    /// Mirrors AudioPlayerService: whether the stream can be skipped within, and whether
    /// playback is behind live. Views observe this manager, not the player.
    @Published private(set) var canSeek = false
    @Published private(set) var isBehindLive = false
    /// How far behind live playback is, in whole seconds; 0 at live or on ICY.
    @Published private(set) var secondsBehindLive: TimeInterval = 0
    @Published var playbackError: String? // Separate error for playback issues
    
    let audioPlayer = AudioPlayerService()
    private let networkService = DRNetworkService()
    private let imageCache = ImageCacheService.shared
    let userPreferences = UserPreferencesService()
    private var cancellables = Set<AnyCancellable>()
    
    // Caching properties
    private var cachedSchedules: [DREpisode] = [] {
        didSet { schedulesByChannel = Self.indexByChannel(cachedSchedules) }
    }
    /// `cachedSchedules` by channel id, rebuilt whenever it is replaced. The programme
    /// lookups run from view bodies — every card, several times per now-playing render —
    /// and each used to filter the whole schedule.
    private var schedulesByChannel: [String: [DREpisode]] = [:]
    /// What DR last said about stations and districts. See `ChannelDirectory`.
    private var channelDirectory = ChannelDirectory()
    private var lastSchedulesUpdate: Date?
    private let cacheValidityDuration: TimeInterval = 10 * 60 // 10 minutes
    
    // Track polling properties
    private var nextLivePollingTime: Date?
    private var isPollingForTrack = false
    
    private let networkMonitor = NetworkMonitor()

    init() {
        setupBindings()
        loadDiskCache()   // Populate UI instantly from disk
        loadChannels()    // Refresh from API in background
        networkMonitor.start { [weak self] online in self?.networkPathChanged(online: online) }
        startScheduleRefresh()
    }

    /// Synchronously loads the last persisted schedules so the UI is populated
    /// immediately on launch without waiting for the network.
    private func loadDiskCache() {
        #if DEBUG
        // UI tests start from their fixtures alone, not from whatever the simulator cached.
        let schedules = UITestFixtures.isActive
            ? (UITestFixtures.seedsCache ? UITestFixtures.schedules() : [])
            : DRLocalCache.shared.load()
        #else
        let schedules = DRLocalCache.shared.load()
        #endif
        guard !schedules.isEmpty else { return }
        cachedSchedules = schedules
        availableChannels = Array(Set(schedules.map { $0.channel }))
            .sorted { $0.title < $1.title }
        // The cached channels carry what the directory said last time, so the next
        // refresh has that to fall back on if `/channels` cannot be reached.
        channelDirectory = ChannelDirectory(learningFrom: availableChannels)
        restoreLastPlayedChannel()
    }
    
    private func setupBindings() {
        audioPlayer.$isPlaying
            .assign(to: \.isPlaying, on: self)
            .store(in: &cancellables)

        audioPlayer.$canSeek
            .assign(to: \.canSeek, on: self)
            .store(in: &cancellables)
        audioPlayer.$isBehindLive
            .assign(to: \.isBehindLive, on: self)
            .store(in: &cancellables)
        // Skipping, pausing and jumping to live all move the moment being heard, so the
        // track and programme are picked again — from what is already fetched, no network.
        audioPlayer.$secondsBehindLive
            .removeDuplicates()
            .sink { [weak self] seconds in
                self?.secondsBehindLive = seconds
                self?.reselectHeard()
            }
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
    
    /// The catalogue fetch in flight, if any. Every screen's `onAppear` asks for the
    /// catalogue when it has none, and before this each ask started a fetch of its own.
    private var catalogueTask: Task<Void, Never>?
    /// The next automatic retry while DR is not answering, and how many have run.
    private var retryTask: Task<Void, Never>?
    private var retryAttempt = 0

    /// Refreshes the catalogue unless what is in memory is recent enough.
    func loadChannels() {
        // In-memory cache still valid — nothing to do
        if !cachedSchedules.isEmpty && isCacheValid() { return }
        startCatalogueFetch()
    }

    /// What every Try Again does: fetch whatever failed now, whatever the cache says.
    func retry() {
        if playbackError != nil, let channel = playingChannel {
            playbackError = nil
            playChannel(channel)
        }
        if catalogueFailure != nil || availableChannels.isEmpty {
            retryAttempt = 0
            startCatalogueFetch()
        }
    }

    @discardableResult
    private func startCatalogueFetch() -> Task<Void, Never> {
        if let catalogueTask { return catalogueTask }

        retryTask?.cancel()
        retryTask = nil
        // Only show loading spinner when there is no data at all (first launch)
        isLoading = availableChannels.isEmpty
        let task = Task { [weak self] in
            guard let self else { return }
            await self.fetchCatalogue()
            self.catalogueTask = nil
            self.isLoading = false
            self.isWaitingLong = false
        }
        catalogueTask = task
        if isLoading { watchForSlowAnswer(to: task) }
        return task
    }

    /// Says "still waiting" if the fetch with nothing on screen runs long, so a slow DR
    /// does not look like a stuck app.
    private func watchForSlowAnswer(to task: Task<Void, Never>) {
        Task { [weak self] in
            try? await Task.sleep(for: ConnectionTiming.slowAfter)
            guard let self, self.catalogueTask == task, self.isLoading else { return }
            self.isWaitingLong = true
        }
    }

    private func fetchCatalogue() async {
        do {
            // Fetched side by side. The directory is a refinement, not a requirement:
            // if it fails, the last one known is used, and failing that channels read
            // their titles as they always did.
            async let fetchedDirectory = try? networkService.fetchChannelDirectory()
            let fetchedSchedules = try await networkService.fetchAllSchedules()
            let directory = await fetchedDirectory ?? self.channelDirectory

            let schedules = fetchedSchedules.map { episode in
                var episode = episode
                episode.channel = directory.apply(to: episode.channel)
                return episode
            }
            let channels = Array(Set(schedules.map { $0.channel })).sorted { $0.title < $1.title }

            self.channelDirectory = directory
            self.cachedSchedules = schedules
            self.lastSchedulesUpdate = Date()
            self.availableChannels = channels
            self.catalogueFailure = nil
            self.retryAttempt = 0
            self.restoreLastPlayedChannel()
            self.refreshCurrentProgram()

            // Persist to disk only after a confirmed successful response — and never
            // fixtures, which would otherwise greet the next ordinary launch.
            #if DEBUG
            if !UITestFixtures.isActive { DRLocalCache.shared.save(schedules) }
            #else
            DRLocalCache.shared.save(schedules)
            #endif

            await self.preloadChannelImages(from: schedules)
        } catch {
            Log.network.error("catalogue fetch failed: \(error.localizedDescription, privacy: .public)")
            // Kept whether or not there are channels to show. It used to be dropped when
            // the disk cache had filled the screen, which left a listener looking at
            // yesterday's programmes with nothing to say they were not today's.
            self.catalogueFailure = RequestFailure(error)
            self.scheduleAutomaticRetry()
        }
    }

    /// While DR is not answering, asks again on a widening interval. Offline is left to
    /// `networkPathChanged`, which knows when it is worth asking.
    private func scheduleAutomaticRetry() {
        guard isOnline, case .drUnavailable = catalogueFailure, retryTask == nil else { return }
        let delay = ConnectionTiming.retryDelay(afterAttempt: retryAttempt)
        retryAttempt += 1
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.retryTask = nil
            Log.network.info("retrying the catalogue while DR is not answering")
            self.startCatalogueFetch()
        }
    }

    /// The connection came or went.
    private func networkPathChanged(online: Bool) {
        guard online != isOnline else { return }
        Log.network.info("network path is \(online ? "online" : "offline", privacy: .public)")
        isOnline = online
        guard online else {
            retryTask?.cancel()
            retryTask = nil
            return
        }
        // Back: fetch what failed or never came, and restart a stream that died with it.
        retryAttempt = 0
        if catalogueFailure != nil || availableChannels.isEmpty || !isCacheValid() {
            startCatalogueFetch()
        }
        if playbackError != nil, audioPlayer.wantsPlayback, let channel = playingChannel {
            playbackError = nil
            playChannel(channel)
        } else {
            audioPlayer.reloadIfStalled()
        }
    }

    /// What to tell the listener about the connection, if anything. See `ConnectionProblem`.
    var connectionProblem: ConnectionProblem? {
        ConnectionProblem.current(isOnline: isOnline,
                                  catalogueFailure: catalogueFailure,
                                  failedStream: playbackError == nil ? nil : playingChannel?.title)
    }

    /// Whether `channel` can be heard right now.
    ///
    /// Not the same as being `playingChannel`, which names whatever is loaded in the player:
    /// a paused channel, and the last-played channel restored at launch without being
    /// started. Marking that one with a speaker left the mark on a card long after the
    /// sound had stopped.
    func isAudible(_ channel: DRChannel) -> Bool {
        Self.isAudible(channel, loaded: playingChannel, isPlaying: isPlaying)
    }

    static func isAudible(_ channel: DRChannel, loaded: DRChannel?, isPlaying: Bool) -> Bool {
        isPlaying && loaded?.id == channel.id
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
    
    func skip(by seconds: TimeInterval) {
        audioPlayer.skip(by: seconds)
    }

    func seekToLive() {
        audioPlayer.seekToLive()
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
    
    /// What selecting a channel should do, given what the player already has.
    enum SelectionAction: Equatable {
        /// Start the stream from scratch: another channel or district, or nothing usable
        /// is loaded (never started this session, or the item failed).
        case restart
        /// The selected channel is loaded and paused: carry on rather than reload.
        case resume
        /// The selected channel is already playing: leave it alone.
        case nothing
    }

    /// Selecting the station that is already on used to tear the stream down and start it
    /// again — an audible gap for nothing. Each district is its own `DRChannel` with its
    /// own `id`, so comparing ids is enough to tell "same channel and district" apart from
    /// "different channel" and "same station, different district".
    static func selectionAction(for channel: DRChannel, loaded: DRChannel?,
                                hasLoadedItem: Bool, isPlaying: Bool) -> SelectionAction {
        guard loaded?.id == channel.id, hasLoadedItem else { return .restart }
        return isPlaying ? .nothing : .resume
    }

    func playChannel(_ channel: DRChannel) {
        switch Self.selectionAction(for: channel, loaded: playingChannel,
                                    hasLoadedItem: audioPlayer.hasLoadedItem,
                                    isPlaying: isPlaying) {
        case .nothing:
            Log.playback.debug("selected the channel already playing; leaving it")
            return
        case .resume:
            Log.playback.debug("selected the paused channel; resuming")
            audioPlayer.resume()
            startPolling(for: channel)
            audioPlayer.updateCommandCenterPlaybackState()
            return
        case .restart:
            break
        }

        recentTracks = []
        heardSnapshot = nil
        heardSnapshotTask?.cancel()
        heardSnapshotTask = nil

        // Switching channels: drop the previous channel's polling before starting the
        // new one, so two loops never run at once.
        stopPolling()
        
        // Get current program from cached schedules
        let currentProgram = liveProgram(for: channel)
        
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
            streamURL = getCachedPrograms(for: channel).first?.streamURL
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
                // Stop what was playing and name the channel that failed. Before, the
                // previous channel played on under an error about this one, and the
                // message could not say which channel it meant.
                self.audioPlayer.stop()
                self.playingChannel = channel
                self.playbackError = "No stream URL available for \(channel.title)"
            }
        }
    }
    
    /// The catalogue as home-screen sections, one per broadcaster that has channels.
    ///
    /// DR is the only source today, so this is a single section — but the home screen
    /// renders whatever this returns, which is what makes adding a broadcaster a data
    /// change rather than a layout one.
    var broadcasterSections: [BroadcasterSection] {
        Broadcaster.sections(from: availableChannels)
    }

    /// The programme the listener is hearing on `channel`.
    ///
    /// For the playing channel while behind live, that is the programme on air at the
    /// moment being heard, which near a boundary is the previous one. Every other channel,
    /// and the playing one at live, is what is on air now.
    func getCurrentProgram(for channel: DRChannel) -> DREpisode? {
        guard channel.id == playingChannel?.id, secondsBehindLive > 0 else {
            return liveProgram(for: channel)
        }
        let date = listeningDate
        let candidates = getCachedPrograms(for: channel)
            + (heardSnapshot.flatMap { $0.channelID == channel.id ? $0.episodes : nil } ?? [])
        return Self.heardProgram(in: candidates, at: date) ?? liveProgram(for: channel)
    }

    static func heardProgram(in programmes: [DREpisode], at date: Date) -> DREpisode? {
        programmes.first { $0.isPlaying(at: date) }
    }

    /// The programme on air now, whatever the listener is hearing. For wall-clock needs:
    /// the stream to start, and when the programme ends for the sleep timer.
    func liveProgram(for channel: DRChannel) -> DREpisode? {
        Self.liveProgram(in: getCachedPrograms(for: channel), at: Date())
    }

    /// The programme on air at `date`, or failing that one whose times DR did not give,
    /// which cannot be judged either way.
    ///
    /// Never one that has ended. This fell back to whatever the channel's first cached
    /// programme was, so a launch from a day-old disk cache, or an hour of DR not answering,
    /// showed long-finished programmes as on air — on every card, the player, the lock
    /// screen, and as the end the sleep timer counted down to.
    static func liveProgram(in programmes: [DREpisode], at date: Date) -> DREpisode? {
        programmes.first { $0.isPlaying(at: date) }
            ?? programmes.first { $0.startDate == nil || $0.endDate == nil }
    }

    // MARK: - What is being heard

    /// The moment being listened to: now, less how far behind live playback is.
    var listeningDate: Date { Date().addingTimeInterval(-secondsBehindLive) }

    /// Whether `track` is what the listener hears now. Views use this rather than
    /// `isCurrentlyPlaying`, which asks about the live edge.
    func isHeard(_ track: DRTrack) -> Bool { track.isPlaying(at: listeningDate) }

    /// The last track list fetched for the playing channel, newest first. DR returns about
    /// the last hour, which covers the ~34 minute DVR window.
    private var recentTracks: [DRTrack] = []

    /// The playing channel's schedule snapshot, fetched only once the listener is behind
    /// live and earlier than the programme `/schedules/all/now` carries. Despite the
    /// endpoint's name it is not "today": it starts with the programme before the one on
    /// air, which is exactly the one a rewind across a boundary lands in.
    private var heardSnapshot: HeardSnapshot?
    private var heardSnapshotTask: Task<Void, Never>?

    struct HeardSnapshot {
        let channelID: String
        let episodes: [DREpisode]
        let fetchedAt: Date
    }

    /// After a failed or empty fetch, wait this long before asking again. Without it a
    /// failure was cached for the channel and never retried; with no wait at all, a paused
    /// listener — whose offset moves every second — would ask every second.
    static let heardSnapshotRetryInterval: TimeInterval = 60

    /// Whether the snapshot is needed and not already in hand.
    static func needsHeardSnapshot(listeningAt date: Date, liveProgrammeStart: Date?,
                                   channelID: String, have snapshot: HeardSnapshot?,
                                   now: Date) -> Bool {
        guard let liveProgrammeStart, date < liveProgrammeStart else { return false }
        guard let snapshot, snapshot.channelID == channelID else { return true }
        return snapshot.episodes.isEmpty
            && now.timeIntervalSince(snapshot.fetchedAt) >= heardSnapshotRetryInterval
    }

    static func heardTrack(in tracks: [DRTrack], at date: Date) -> DRTrack? {
        tracks.first { $0.isPlaying(at: date) }
    }

    /// Picks the track and programme for the moment being heard and publishes them if they
    /// changed.
    private func reselectHeard() {
        guard let channel = playingChannel else { return }
        let date = listeningDate
        let track = Self.heardTrack(in: recentTracks, at: date)
        loadHeardSnapshotIfNeeded(for: channel, at: date)
        let program = getCurrentProgram(for: channel)
        guard track != currentTrack || program?.id != currentLiveProgram?.id else { return }
        Log.playback.debug("heard: \(track?.title ?? "no track", privacy: .public) at \(Int(self.secondsBehindLive)) s behind live")
        currentTrack = track
        currentLiveProgram = program
        audioPlayer.updateCommandCenterInfo(channel: channel, program: program, track: track)
    }

    private func loadHeardSnapshotIfNeeded(for channel: DRChannel, at date: Date) {
        guard heardSnapshotTask == nil,
              Self.needsHeardSnapshot(listeningAt: date,
                                      liveProgrammeStart: liveProgram(for: channel)?.startDate,
                                      channelID: channel.id, have: heardSnapshot, now: Date())
        else { return }
        Log.playback.debug("behind live past the programme start; fetching the schedule snapshot")
        heardSnapshotTask = Task { [weak self] in
            guard let self else { return }
            let episodes = await self.loadSchedule(for: channel)
            await MainActor.run {
                self.heardSnapshotTask = nil
                guard self.playingChannel?.id == channel.id else { return }
                self.heardSnapshot = HeardSnapshot(channelID: channel.id, episodes: episodes,
                                                   fetchedAt: Date())
                self.reselectHeard()
            }
        }
    }
    
    /// Today's full schedule for a channel.
    ///
    /// `/schedules/all/now` only carries what is on air right now, so the rest of the
    /// day comes from the snapshot endpoint — which `DRNetworkService` has always
    /// implemented and nothing has ever called.
    func loadSchedule(for channel: DRChannel) async -> [DREpisode] {
        (try? await fetchSchedule(for: channel)) ?? []
    }

    /// As `loadSchedule`, but saying why it failed — for the schedule sheets, which used to
    /// show "No schedule" for a dead connection as if DR had nothing to list.
    func fetchSchedule(for channel: DRChannel) async throws -> [DREpisode] {
        do {
            return try await networkService.fetchScheduleSnapshot(for: channel.slug).items
        } catch {
            Log.network.error(
                "schedule snapshot failed for \(channel.slug, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
    
    func getCachedPrograms(for channel: DRChannel) -> [DREpisode] {
        schedulesByChannel[channel.id] ?? []
    }

    /// Groups `schedules` by channel id, each channel's programmes in their original order:
    /// the lookups take the first match, so the order is part of the answer.
    static func indexByChannel(_ schedules: [DREpisode]) -> [String: [DREpisode]] {
        Dictionary(grouping: schedules, by: \.channel.id)
    }

    /// Artwork for what is on the channel now, falling back to any cached programme for it.
    ///
    /// The fallback is not hypothetical: `/schedules/all/now` returns entries with no image
    /// often enough that a card would otherwise show an empty placeholder while a perfectly
    /// good image sat in the schedule cache.
    func artworkURL(for channel: DRChannel) -> URL? {
        if let url = getCurrentProgram(for: channel)?.primaryImageURL {
            return URL(string: url)
        }
        let cached = getCachedPrograms(for: channel)
        if let url = cached.first(where: { $0.primaryImageURL != nil })?.primaryImageURL {
            return URL(string: url)
        }
        return nil
    }

    // MARK: - Deep Link Resolution

    /// Resolves the identifier carried by a deep link to a real channel.
    ///
    /// Two link formats exist and they do not agree on what identifies a channel:
    ///
    ///   - `DeepLinkHandler.generateDeepLinkURL` emits `lytter:///channel/<id>`, where id
    ///     is an opaque URN such as `urn:dr:radio:channel:5fa156d1da351264f87b462d`.
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

            return await MainActor.run {
                self.recentTracks = indexPoints.items
                let currentTrack = Self.heardTrack(in: indexPoints.items, at: self.listeningDate)
                self.currentTrack = currentTrack
                
                // Update Command Center with new track information
                let currentProgram = self.getCurrentProgram(for: channel)
                self.audioPlayer.updateCommandCenterInfo(channel: channel, program: currentProgram, track: currentTrack)
                return currentTrack
            }
        } catch {
            // Keep what is known only while it is still true. The last track used to stay
            // on screen however long ago it ended, for as long as the polls kept failing.
            reselectHeard()
            return nil
        }
    }
    
    
    
    private var trackPollingTask: Task<Void, Never>?
    
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
                let behind = await MainActor.run { self.secondsBehindLive }
                if let track, let endTime = track.endTime,
                   endTime.addingTimeInterval(behind) > Date() {
                    delay = max(endTime.timeIntervalSinceNow + behind + DRAPIConfig.trackUpdateBuffer, 1)
                } else {
                    delay = DRAPIConfig.trackPollingInterval
                }
                await MainActor.run {
                    self.nextLivePollingTime = Date().addingTimeInterval(delay)
                }
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
    
    /// Stops the track loop. Cancellation is real now: `Task.sleep` throws on cancel and the
    /// loop checks `Task.isCancelled`, so nothing is left in flight.
    private func stopPolling() {
        trackPollingTask?.cancel()
        trackPollingTask = nil
        isPollingForTrack = false
        nextLivePollingTime = nil
    }
    
    
    
    // MARK: - Sleep Timer

    /// The active sleep timer, if any.
    @Published private(set) var sleepTimer: SleepTimer?

    /// Seconds left, republished every tick so the UI can count down without owning a
    /// timer of its own.
    @Published private(set) var sleepTimerRemaining: TimeInterval = 0

    private var sleepTimerTask: Task<Void, Never>?

    /// Starts a sleep timer, replacing any existing one.
    ///
    /// Returns false when the mode cannot be satisfied — `.endOfProgramme` on a channel
    /// whose schedule the API did not give us, which is a real case rather than a
    /// theoretical one.
    @discardableResult
    func startSleepTimer(_ mode: SleepTimerMode) -> Bool {
        let programmeEnd = playingChannel.flatMap { liveProgram(for: $0)?.endDate }
        guard let timer = SleepTimer(mode: mode, from: Date(), programmeEnd: programmeEnd) else {
            Log.playback.warning("sleep timer rejected: no end time for the current programme")
            return false
        }

        sleepTimer = timer
        sleepTimerRemaining = timer.remaining(at: Date())
        runSleepTimer(timer)
        return true
    }

    func cancelSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimer = nil
        sleepTimerRemaining = 0
        // Undo a fade that was already partway down.
        audioPlayer.setVolume(1)
    }

    /// Ticks once a second. The timer itself is a deadline, so this only reads the clock —
    /// a tick that arrives late, or not at all while suspended, cannot make it drift.
    private func runSleepTimer(_ timer: SleepTimer) {
        sleepTimerTask?.cancel()
        sleepTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let now = Date()

                self.sleepTimerRemaining = timer.remaining(at: now)
                self.audioPlayer.setVolume(timer.volumeMultiplier(at: now))

                if timer.hasFired(at: now) {
                    self.sleepTimerDidFire()
                    return
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func sleepTimerDidFire() {
        Log.playback.debug("sleep timer fired")

        if isPlaying {
            // The default pause() is the deliberate kind, which is right: this stop should
            // stand, not be undone by an interruption ending later.
            audioPlayer.pause()
            stopPolling()
            audioPlayer.updateCommandCenterPlaybackState()
        }

        // Restore the volume the fade took down, or the next play starts silent.
        audioPlayer.setVolume(1)

        sleepTimer = nil
        sleepTimerRemaining = 0
        sleepTimerTask = nil
    }


    // MARK: - Keeping the schedule current

    /// `/schedules/all/now` is the schedule, and it only carries what is on air at the
    /// moment it is asked. So it has to be asked again as programmes end — at first that
    /// happened only at launch, then every five minutes while playing, which left every
    /// card on Home showing what was on when the app opened.
    private var scheduleRefreshTask: Task<Void, Never>?

    /// Whether the app is in front. Refreshing is for someone looking or listening: in the
    /// background with nothing playing, there is no one to refresh for.
    private var isAppActive = true

    /// Past this, a refresh is due even if no programme has ended — DR changes its plans.
    private static let scheduleMaxAge: TimeInterval = 10 * 60
    /// After a programme's end, how long to give DR to move on to the next.
    private static let boundaryBuffer: TimeInterval = 5
    /// However the programmes fall, wake no sooner and no later than these.
    private static let refreshBounds: ClosedRange<TimeInterval> = 60...(10 * 60)

    /// Called by the app as its scene comes and goes.
    func setAppActive(_ active: Bool) {
        isAppActive = active
        if active { refreshScheduleIfNeeded() }
    }

    /// Whether to fetch the schedule again: never fetched, fetched too long ago, or a
    /// programme in it has ended.
    static func needsScheduleRefresh(_ programmes: [DREpisode], lastFetched: Date?,
                                     now: Date) -> Bool {
        guard let lastFetched, now.timeIntervalSince(lastFetched) < scheduleMaxAge else {
            return true
        }
        return hasEnded(programmes, at: now)
    }

    static func hasEnded(_ programmes: [DREpisode], at now: Date) -> Bool {
        programmes.contains { ($0.endDate ?? .distantFuture) <= now }
    }

    /// How long until the next refresh: just after the soonest programme still on air ends.
    static func scheduleRefreshDelay(_ programmes: [DREpisode], now: Date) -> TimeInterval {
        let nextEnd = programmes.compactMap(\.endDate).filter { $0 > now }.min()
        let delay = nextEnd.map { $0.timeIntervalSince(now) + boundaryBuffer }
            ?? refreshBounds.upperBound
        return min(max(delay, refreshBounds.lowerBound), refreshBounds.upperBound)
    }

    private func startScheduleRefresh() {
        scheduleRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                // Read without holding self across the sleep.
                guard let delay = self.map({ Self.scheduleRefreshDelay($0.cachedSchedules,
                                                                       now: Date()) })
                else { return }
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, let self else { return }
                self.refreshScheduleIfNeeded()
            }
        }
    }

    private func refreshScheduleIfNeeded() {
        let now = Date()
        // A programme that ended is no longer drawn as on air, whether or not a fetch
        // follows — offline, none will. The views ask on every render; this is what
        // makes them render.
        if Self.hasEnded(cachedSchedules, at: now) {
            objectWillChange.send()
            refreshCurrentProgram()
        }
        guard isAppActive || audioPlayer.wantsPlayback, isOnline,
              Self.needsScheduleRefresh(cachedSchedules, lastFetched: lastSchedulesUpdate,
                                        now: now)
        else { return }
        startCatalogueFetch()
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
        // Show Images off is a request for less data; fetching every picture anyway would
        // spend it on images nothing draws.
        guard userPreferences.showsArtwork else { return }
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
    /// Order-preserving.
    ///
    /// This was `Array(Set(self))`, which discards order — and Swift seeds its hashing
    /// per process, so the district list under P4 and P5 came out in a different order on
    /// every launch.
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
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

    /// Whether the full player is presented.
    ///
    /// This cannot live in the mini player. The mini player is the tab bar's bottom
    /// accessory, and `LiquidGlassMiniPlayer` switches on
    /// `tabViewBottomAccessoryPlacement` — so SwiftUI rebuilds it from a different
    /// branch whenever the placement changes, which is exactly what covering the tab bar
    /// with a sheet does. A `@State` flag there was destroyed on that rebuild and the
    /// sheet dismissed itself the moment it appeared. The `.id(playingChannel?.id)` on
    /// the accessory threw the same state away whenever the channel changed.
    @Published var isShowingFullPlayer = false
    
    func selectChannel(_ channel: DRChannel, showSheet: Bool = false) {
        selectedChannel = channel
    }
}
