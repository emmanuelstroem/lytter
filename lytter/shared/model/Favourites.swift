//
//  Favourites.swift
//  lytter
//

import Foundation

/// The channels someone has pinned, in the order they pinned them.
///
/// Channels rather than stations, deliberately. P4 and P5 are ten district channels each,
/// reached through a picker sheet — so pinning *P4 København* specifically is what removes
/// the repeated interaction. Pinning "P4" would still leave the picker in the way.
///
/// Order is insertion order and is preserved: a `Set` would reshuffle the list between
/// launches, which is the same trap `uniqued()` fell into (P15).
struct Favourites: Equatable {

    private(set) var channelIDs: [String]

    init(channelIDs: [String] = []) {
        // Defensive against a persisted list that somehow gained duplicates: two entries
        // for one channel would render as two identical cards.
        var seen = Set<String>()
        self.channelIDs = channelIDs.filter { seen.insert($0).inserted }
    }

    var isEmpty: Bool { channelIDs.isEmpty }

    func contains(_ channelID: String) -> Bool {
        channelIDs.contains(channelID)
    }

    /// Adds to the end, so the list reads in the order things were pinned.
    mutating func add(_ channelID: String) {
        guard !contains(channelID) else { return }
        channelIDs.append(channelID)
    }

    mutating func remove(_ channelID: String) {
        channelIDs.removeAll { $0 == channelID }
    }

    @discardableResult
    mutating func toggle(_ channelID: String) -> Bool {
        if contains(channelID) {
            remove(channelID)
            return false
        }
        add(channelID)
        return true
    }

    /// The favourites among `channels`, in favourite order rather than catalogue order.
    ///
    /// Silently drops ids the catalogue no longer has — DR retires channels, and a stale
    /// id should not leave a gap or a placeholder card.
    func resolve(in channels: [DRChannel]) -> [DRChannel] {
        let byID = Dictionary(channels.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return channelIDs.compactMap { byID[$0] }
    }
}
