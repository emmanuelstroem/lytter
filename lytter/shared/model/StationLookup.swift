//
//  StationLookup.swift
//  lytter
//

import Foundation

/// Which channels a spoken or typed station name means, for Siri and Shortcuts (F15).
///
/// Search lists results for a person to choose from; Siri has to act on one. So this
/// resolves further than `GroupedChannel.searchResult`: "P4" names a station of ten
/// districts, and when the listener has a region it means their district — the one the
/// app would put first anyway. Only without a region does it return all ten, and Siri
/// asks which.
enum StationLookup {

    static func channels(answering query: String, in channels: [DRChannel],
                         region: District?) -> [DRChannel] {
        GroupedChannel.grouped(from: channels)
            .compactMap { $0.searchResult(for: query) }
            .flatMap { group -> [DRChannel] in
                if group.hasMultipleDistricts, let region, let mine = group.channel(in: region) {
                    return [mine]
                }
                return group.channels
            }
    }
}

/// The catalogue, for Siri — an App Intent or the media intent may have started the app a
/// moment ago, with nothing loaded yet.
enum StationCatalogue {

    /// The channels, waiting briefly for them if the app has none yet.
    ///
    /// Usually immediate: the disk cache is read synchronously at launch. On a first run,
    /// or with the cache cleared, an intent that launched the app has to wait for the
    /// fetch the launch started.
    static func channels(waitingUpTo limit: Duration = .seconds(10)) async -> [DRChannel] {
        let manager = DRServiceManager.shared
        if manager.availableChannels.isEmpty && !manager.isLoading {
            manager.loadChannels()
        }
        let clock = ContinuousClock()
        let deadline = clock.now + limit
        while manager.availableChannels.isEmpty && clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(200))
        }
        return manager.availableChannels
    }
}
