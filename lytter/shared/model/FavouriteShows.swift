//
//  FavouriteShows.swift
//  lytter
//

import Foundation

/// A programme someone has pinned (F33): a DR series, wherever and whenever it airs.
///
/// Unlike a favourite channel, its title and artwork are stored. A channel is always in the
/// catalogue; a show is in it only while it is on air, so on any other day nothing could
/// name it.
nonisolated struct FavouriteShow: Codable, Equatable, Identifiable {
    /// DR's series URN, `urn:dr:radio:series:…`, the same across every airing.
    let seriesID: String
    var title: String
    var imageURL: String?
    /// Slugs of the channels it has been seen on, in the order they were seen. What a
    /// constrained network still fetches, so the shelf can say when it is on.
    var channelSlugs: [String]

    var id: String { seriesID }

    /// The show `episode` belongs to, or nil for an entry with no series — a news bulletin
    /// or a one-off that DR files under nothing.
    init?(episode: DREpisode) {
        guard let series = episode.series, !series.id.isEmpty else { return nil }
        self.init(seriesID: series.id, title: episode.programmeName,
                  imageURL: episode.squareImageURL ?? episode.primaryImageURL,
                  channelSlugs: [episode.channel.slug])
    }

    init(seriesID: String, title: String, imageURL: String?, channelSlugs: [String]) {
        self.seriesID = seriesID
        self.title = title
        self.imageURL = imageURL
        self.channelSlugs = channelSlugs
    }
}

/// The shows someone has pinned, in the order they pinned them — `Favourites`, for series.
struct FavouriteShows: Equatable {

    private(set) var shows: [FavouriteShow]

    init(shows: [FavouriteShow] = []) {
        var seen = Set<String>()
        self.shows = shows.filter { seen.insert($0.seriesID).inserted }
    }

    var isEmpty: Bool { shows.isEmpty }

    var seriesIDs: Set<String> { Set(shows.map(\.seriesID)) }

    /// Every channel any favourite show has been seen on.
    var channelSlugs: Set<String> { Set(shows.flatMap(\.channelSlugs)) }

    func contains(_ seriesID: String) -> Bool {
        shows.contains { $0.seriesID == seriesID }
    }

    /// Adds to the end. A show already pinned keeps its place.
    mutating func add(_ show: FavouriteShow) {
        guard !contains(show.seriesID) else { return }
        shows.append(show)
    }

    mutating func remove(_ seriesID: String) {
        shows.removeAll { $0.seriesID == seriesID }
    }

    @discardableResult
    mutating func toggle(_ show: FavouriteShow) -> Bool {
        if contains(show.seriesID) {
            remove(show.seriesID)
            return false
        }
        add(show)
        return true
    }

    /// Brings a pinned show up to date with an airing of it: DR renames series and changes
    /// their artwork, and a show can move to, or also air on, another channel. Returns
    /// whether anything changed, so an unchanged list is not written again.
    @discardableResult
    mutating func update(from episode: DREpisode) -> Bool {
        guard let seen = FavouriteShow(episode: episode),
              let index = shows.firstIndex(where: { $0.seriesID == seen.seriesID }) else {
            return false
        }
        var show = shows[index]
        show.title = seen.title
        show.imageURL = seen.imageURL ?? show.imageURL
        if !show.channelSlugs.contains(episode.channel.slug) {
            show.channelSlugs.append(episode.channel.slug)
        }
        guard show != shows[index] else { return false }
        shows[index] = show
        return true
    }
}
