//
//  DRAssets.swift
//  lytter
//

import Foundation

// MARK: - Series Models
nonisolated struct DRSeries: Codable, Equatable {
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
nonisolated struct DRAudioAsset: Codable, Equatable {
    let type: String
    let target: String
    let isStreamLive: Bool?
    let format: String
    let bitrate: Int?
    let url: String
}

// MARK: - Image Asset Models
nonisolated struct DRImageAsset: Codable, Equatable {
    let id: String
    let target: String
    let ratio: String
    let format: String
    let blurHash: String?
    
    var imageURL: String {
        return DRAPIConfig.imageURL(for: id)
    }
}
