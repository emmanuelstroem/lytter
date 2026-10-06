//
//  DRTrack.swift
//  lytter
//

import Foundation

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
