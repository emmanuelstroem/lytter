//
//  BroadcasterSource.swift
//  lytter
//

import Foundation

/// Where one broadcaster's channels come from.
///
/// Deliberately small: what is on air on each channel now, which is all the catalogue is
/// built from. What only DR offers — a channel's whole day, the tracks being played,
/// catch-up — stays DR's own calls until a second source offers it too.
///
/// Rules for a new source:
/// - Channel ids are URNs in the source's own namespace (`urn:lytter:<broadcaster>:…`).
///   They are what favourites, recently played, widgets and Siri store, so two sources
///   must never mint the same one. DR's are `urn:dr:radio:channel:…`.
/// - Every channel it returns sets `broadcasterID` to its broadcaster's id.
/// - Favourite shows key on channel *slug*, which only DR's schedules use today. A source
///   with schedules of its own needs slugs that cannot collide with DR's first.
/// - Its catalogue is saved in DR's disk cache with the rest. Give it its own before
///   shipping one.
protocol BroadcasterSource: AnyObject, Sendable {

    /// Who this source speaks for.
    static var broadcaster: Broadcaster { get }

    init()

    /// What is on air now, one or more programmes per channel. The channels are read from
    /// these, so a channel with nothing scheduled is not listed.
    func fetchCatalogue() async throws -> [DREpisode]

    /// Before the first fetch: the channels this source supplied last time, from the disk
    /// cache, for a source that can learn something from them.
    func restore(from cached: [DRChannel])
}

extension BroadcasterSource {
    func restore(from cached: [DRChannel]) {}
}

/// The catalogue from every source, asked side by side.
enum Catalogue {

    /// Every source's programmes, in the sources' order.
    ///
    /// A source that fails is left out, so one broadcaster that is down does not take the
    /// others with it. Only when every source fails does the fetch fail, with the first
    /// source's error — which is DR's, and what the connection banner describes.
    static func fetch(from sources: [any BroadcasterSource]) async throws -> [DREpisode] {
        var results = [Result<[DREpisode], any Error>?](repeating: nil, count: sources.count)
        await withTaskGroup(of: (Int, Result<[DREpisode], any Error>).self) { group in
            for (index, source) in sources.enumerated() {
                group.addTask {
                    do { return (index, .success(try await source.fetchCatalogue())) }
                    catch { return (index, .failure(error)) }
                }
            }
            for await (index, result) in group { results[index] = result }
        }
        return try merge(results.compactMap { $0 })
    }

    /// The pure half of `fetch`, separate so it can be tested without a network.
    static func merge(_ results: [Result<[DREpisode], any Error>]) throws -> [DREpisode] {
        var episodes: [DREpisode] = []
        var firstError: (any Error)?
        var anySucceeded = false
        for result in results {
            switch result {
            case .success(let fetched):
                episodes += fetched
                anySucceeded = true
            case .failure(let error):
                firstError = firstError ?? error
            }
        }
        if !anySucceeded, let firstError { throw firstError }
        return episodes
    }
}
