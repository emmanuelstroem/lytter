//
//  DRAPIConfig.swift
//  lytter
//

import Foundation

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
    /// A channel's whole broadcast day: `schedules/{slug}/{yyyy-MM-dd}`. The only schedule
    /// that reaches back past the previous programme, which is what catch-up needs (F16).
    nonisolated static let schedules = "\(baseURL)/schedules"
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
