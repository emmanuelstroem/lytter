    //
    //  DRNetworkService.swift
    //  ios
    //
    //  Created by Emmanuel on 27/07/2025.
    //

import Foundation

    // MARK: - iOS DR Network Service

class DRNetworkService {
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
        self.decoder.keyDecodingStrategy = .useDefaultKeys
    }
    
        // MARK: - Fetch All Schedules
    func fetchAllSchedules() async throws -> [DREpisode] {
        let url = URL(string: DRAPIConfig.schedulesAllNow)!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        do {
                // Decode as DRScheduleItem array first
            let scheduleItems = try decoder.decode([DRScheduleItem].self, from: data)
            
                // Convert to DREpisode objects
            let episodes = scheduleItems.map { $0.toEpisode() }
            
            return episodes
        } catch {
            throw NetworkError.decodingError
        }
    }
    
        // MARK: - Fetch Schedule Snapshot for Channel
    func fetchScheduleSnapshot(for channelSlug: String) async throws -> DRScheduleResponse {
        let url = URL(string: "\(DRAPIConfig.scheduleSnapshot)/\(channelSlug)")!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        do {
            let schedule = try decoder.decode(DRScheduleResponse.self, from: data)
            return schedule
        } catch {
            throw NetworkError.decodingError
        }
    }
    
        // MARK: - Fetch Index Points (Currently Playing Tracks)
    func fetchIndexPoints(for channelSlug: String) async throws -> DRIndexPointsResponse {
        let url = URL(string: "\(DRAPIConfig.indexpointsLive)/\(channelSlug)")!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        do {
            let indexPoints = try decoder.decode(DRIndexPointsResponse.self, from: data)
            return indexPoints
        } catch {
            throw NetworkError.decodingError
        }
    }
    
        // MARK: - Fetch Image Data
    func fetchImageData(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        return data
    }
}

    // MARK: - Network Error

enum NetworkError: Error, LocalizedError {
    case invalidResponse
    case invalidData
    case decodingError
    case invalidURL
    case noInternetConnection
    case serverError
    
    var errorDescription: String? {
        switch self {
            case .invalidResponse:
                return "Invalid response from server"
            case .invalidData:
                return "Invalid data received"
            case .decodingError:
                return "Failed to decode response"
            case .invalidURL:
                return "Invalid URL"
            case .noInternetConnection:
                return "No internet connection"
            case .serverError:
                return "Server error"
        }
    }
} 
