//
//  TopShelfNetworkService.swift
//  TopShelfExtension
//
//  Created by Emmanuel on 09/08/2025.
//

import Foundation

// MARK: - TopShelf API Configuration
struct TopShelfAPIConfig {
    static let baseURL = "https://api.dr.dk/radio/v4"
    static let assetBaseURL = "https://asset.dr.dk/drlyd/images"
    static let schedulesAllNow = "\(baseURL)/schedules/all/now"
    
    static func imageURL(for imageAssetURN: String) -> String {
        return "\(assetBaseURL)/\(imageAssetURN)"
    }
}

// MARK: - Simplified Models for TopShelf
struct TopShelfChannel: Codable, Identifiable {
    let id: String
    let title: String
    let slug: String
    let type: String
    
    var name: String {
        let components = title.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        return components.first.map(String.init) ?? title
    }
    
    var district: String? {
        let components = title.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        return components.count > 1 ? String(components[1]) : nil
    }
}

struct TopShelfImageAsset: Codable {
    let id: String
    let target: String
    let ratio: String
    let format: String
    
    var imageURL: String {
        return TopShelfAPIConfig.imageURL(for: id)
    }
}

struct TopShelfEpisode: Codable {
    let id: String
    let title: String
    let channel: TopShelfChannel
    let imageAssets: [TopShelfImageAsset]?
    
    var squareImageURL: String? {
        return imageAssets?.first(where: { $0.target == "SquareImage" })?.imageURL
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
}

struct TopShelfScheduleItem: Codable {
    let channel: TopShelfChannel
    let title: String?
    let imageAssets: [TopShelfImageAsset]?
    
    func toEpisode() -> TopShelfEpisode {
        return TopShelfEpisode(
            id: channel.id,
            title: title ?? channel.title,
            channel: channel,
            imageAssets: imageAssets
        )
    }
}

// MARK: - TopShelf Network Service
class TopShelfNetworkService {
    private let session: URLSession
    private let decoder: JSONDecoder
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    func fetchChannelsWithImages() async throws -> [TopShelfEpisode] {
        let url = URL(string: TopShelfAPIConfig.schedulesAllNow)!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TopShelfError.networkError
        }
        
        do {
            let scheduleItems = try decoder.decode([TopShelfScheduleItem].self, from: data)
            return scheduleItems.map { $0.toEpisode() }
        } catch {
            print("⚠️ TopShelf: Decoding error: \(error)")
            throw TopShelfError.decodingError
        }
    }
}

// MARK: - TopShelf Error
enum TopShelfError: Error {
    case networkError
    case decodingError
    case noData
}