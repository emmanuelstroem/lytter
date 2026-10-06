//
//  DRSource.swift
//  lytter
//

import Foundation

/// DR's catalogue: what is on air on every DR channel, named the way DR's channel
/// directory names them.
final class DRSource: BroadcasterSource {

    static let broadcaster = Broadcaster.dr

    /// Also what `DRServiceManager` asks for what only DR offers — a channel's day, its
    /// tracks, catch-up — so every DR request goes out on the one session.
    let network = DRNetworkService()

    /// What DR last said about stations and districts. See `ChannelDirectory`.
    private var directory = ChannelDirectory()

    init() {}

    /// The cached channels carry what the directory said last time, so the next refresh
    /// has that to fall back on if `/channels` cannot be reached.
    func restore(from cached: [DRChannel]) {
        directory = ChannelDirectory(learningFrom: cached)
    }

    func fetchCatalogue() async throws -> [DREpisode] {
        // Fetched side by side. The directory is a refinement, not a requirement:
        // if it fails, the last one known is used, and failing that channels read
        // their titles as they always did.
        async let fetchedDirectory = try? network.fetchChannelDirectory()
        let fetchedSchedules = try await network.fetchAllSchedules()
        let directory = await fetchedDirectory ?? self.directory

        self.directory = directory
        return fetchedSchedules.map { episode in
            var episode = episode
            episode.channel = directory.apply(to: episode.channel)
            return episode
        }
    }
}
