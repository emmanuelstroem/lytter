//
//  RecentlyPlayed.swift
//  lytter
//

import Foundation

/// The channels most recently listened to, newest first.
///
/// `UserPreferencesService` already stored a single `lastPlayedChannel`, for restoring the
/// mini player at launch. That stays: it keeps a title and district alongside the id so the
/// player can be populated before the catalogue loads. This is the *history*, and it stores
/// ids only — a name copied here would go stale when DR renames something.
struct RecentlyPlayed: Equatable {

    /// Enough to be useful on a shelf, few enough that the list stays recognisable. A
    /// history you have to scroll is not a shortcut.
    static let limit = 10

    private(set) var channelIDs: [String]

    init(channelIDs: [String] = []) {
        var seen = Set<String>()
        self.channelIDs = channelIDs.filter { seen.insert($0).inserted }.prefix(Self.limit).map { $0 }
    }

    var isEmpty: Bool { channelIDs.isEmpty }

    /// Records a play, moving the channel to the front.
    ///
    /// Re-playing something already in the list moves it rather than duplicating it, which
    /// is why this cannot just append — the common case is returning to the same two or
    /// three stations.
    mutating func record(_ channelID: String) {
        channelIDs.removeAll { $0 == channelID }
        channelIDs.insert(channelID, at: 0)
        if channelIDs.count > Self.limit {
            channelIDs.removeLast(channelIDs.count - Self.limit)
        }
    }

    /// The history as channels, newest first, skipping ids the catalogue no longer has.
    func resolve(in channels: [DRChannel]) -> [DRChannel] {
        let byID = Dictionary(channels.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return channelIDs.compactMap { byID[$0] }
    }
}
