//
//  DREpisode.swift
//  lytter
//

import Foundation

// MARK: - Episode/Program Models
nonisolated struct DREpisode: Identifiable, Codable, Equatable {
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

    /// The recording of this broadcast, for catch-up listening (F16), or nil when DR does
    /// not offer one.
    ///
    /// Never the live stream. A programme on air carries the channel's live assets
    /// (`isStreamLive`), and `streamURL` falls back to whatever comes first, so it cannot be
    /// asked. DR sends HLS and several progressive files for a recording; HLS adapts its
    /// bitrate and starts without downloading the whole file, so it is preferred.
    var onDemandStreamURL: String? {
        guard isAvailableOnDemand else { return nil }
        let recorded = (audioAssets ?? []).filter { $0.isStreamLive != true }
        return (recorded.first { $0.target == "Stream" && $0.format == "HLS" }
                ?? recorded.first { $0.target == "Progressive" })?.url
    }

    /// Whether this broadcast can be listened back to at `date`: it has finished, and DR
    /// has a recording of it.
    ///
    /// Finished, not merely recorded. DR marks repeats as available hours before they air —
    /// tonight's rerun of this morning's programme already has its file — and a "Play" on a
    /// row under "upcoming" reads as a promise to tune in when it starts.
    func isCatchUp(at date: Date) -> Bool {
        guard let end = endDate, end <= date else { return false }
        return onDemandStreamURL != nil
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

// MARK: - Image Asset Extensions
extension DREpisode {
    /// Returns all image URLs from this episode
    var allImageURLs: [String] {
        guard let imageAssets = imageAssets else { return [] }
        return imageAssets.map { $0.imageURL }
    }
}
