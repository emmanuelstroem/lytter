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

    // MARK: - Request builder
    private func makeRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("lytter/1.0 tvOS", forHTTPHeaderField: "User-Agent")
        if let key = DRAPIConfig.subscriptionKey {
            request.setValue(key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        }
        return request
    }

    // MARK: - Fetch All Schedules (with retry)
    func fetchAllSchedules(retries: Int = 3) async throws -> [DREpisode] {
        let url = URL(string: DRAPIConfig.schedulesAllNow)!
        var lastError: Error = NetworkError.invalidResponse

        for attempt in 0..<retries {
            if attempt > 0 {
                // Exponential backoff: 1s, 2s
                try await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
            }

            do {
                let (data, response) = try await session.data(for: makeRequest(for: url))

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw NetworkError.httpError(httpResponse.statusCode)
                }

                let scheduleItems = try decoder.decode([DRScheduleItem].self, from: data)
                return scheduleItems.map { $0.toEpisode() }
            } catch NetworkError.decodingError {
                // Decoding errors are not transient — fail immediately
                throw NetworkError.decodingError
            } catch {
                lastError = error
                // Retry on network/server errors
            }
        }

        throw lastError
    }

    // MARK: - Fetch Schedule Snapshot for Channel
    func fetchScheduleSnapshot(for channelSlug: String) async throws -> DRScheduleResponse {
        let url = URL(string: "\(DRAPIConfig.scheduleSnapshot)/\(channelSlug)")!
        let (data, response) = try await session.data(for: makeRequest(for: url))

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(DRScheduleResponse.self, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }

    // MARK: - Fetch Index Points (Currently Playing Tracks)
    func fetchIndexPoints(for channelSlug: String) async throws -> DRIndexPointsResponse {
        let url = URL(string: "\(DRAPIConfig.indexpointsLive)/\(channelSlug)")!
        let (data, response) = try await session.data(for: makeRequest(for: url))

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(DRIndexPointsResponse.self, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }

    // MARK: - Fetch Image Data
    func fetchImageData(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }

        let (data, response) = try await session.data(for: makeRequest(for: url))

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        return data
    }
}

    // MARK: - Network Error

enum NetworkError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int)
    case invalidData
    case decodingError
    case invalidURL
    case noInternetConnection
    case serverError

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Could not reach the server. Please check your connection."
        case .httpError(let code):
            switch code {
            case 401:
                // api.dr.dk answers 401 for any path under /radio/ that it does not serve,
                // so this nearly always means the API version was retired rather than that
                // a key is missing. Lead with the likely cause.
                return """
                    DR's API rejected the request (401). The app is using API version \
                    \(DRAPIConfig.apiVersion), which DR may have retired — check \
                    https://www.dr.dk/lyd for the version currently in use and update \
                    DRAPIConfig.apiVersion. If that version is correct, the API may now \
                    require a subscription key from developer.dr.dk.
                    """
            case 403: return "API access forbidden (403). Check your subscription key."
            case 404: return "Channel data not found (404). Try again later."
            case 429: return "Too many requests. Please wait a moment and retry."
            case 500...599: return "DR server error (\(code)). Try again later."
            default: return "Unexpected server response (\(code))."
            }
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
