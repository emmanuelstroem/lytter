//
//  DRAPIResponses.swift
//  lytter
//

import Foundation

// MARK: - Schedule Response Models
struct DRScheduleResponse: Codable, Equatable {
    let type: String
    let channel: DRChannel
    let items: [DREpisode]
    let scheduleDate: String?

    /// One broadcast day: `day`, DR's full schedule for a date, with `snapshot` folded in.
    ///
    /// The snapshot starts with the programme before the one on air, and in the small hours
    /// that one belongs to the previous broadcast day — DR's day runs from about 05:00 — so
    /// neither list covers the other. Keyed by broadcast, as the sheets are: the same episode
    /// airs more than once a day.
    static func mergedDay(_ day: [DREpisode], snapshot: [DREpisode]) -> [DREpisode] {
        (day + snapshot)
            .uniqued(by: \.broadcastID)
            .sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
    }
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
