//
//  TrackPolling.swift
//  lytter
//

import Foundation

/// When the track loop asks DR's `indexpoints/live` again.
///
/// Just after the song being heard ends, as it always has. With no song playing — a talk
/// channel, the news, the moments before DR lists the next song — it used to ask every
/// 15 s, which on P1 is 240 requests a listening hour for a track that is not there. Now
/// each poll in a row that finds no song waits longer: 15 s, 30 s, then a minute, until a
/// song appears and the count starts again.
struct TrackPolling {

    /// Polls in a row that have found no song playing.
    private(set) var idlePolls = 0

    /// How long to wait after a poll that found `heard` playing, or nothing.
    ///
    /// - Parameters:
    ///   - heard: the song being heard, if any.
    ///   - known: every track DR listed. Behind live, the next song may be among them
    ///     already; the wait then ends as it starts, rather than up to a minute after.
    ///   - behind: how far behind live the listener is.
    mutating func delay(heard: DRTrack?, known: [DRTrack], secondsBehindLive behind: TimeInterval,
                        now: Date) -> TimeInterval {
        let listening = now.addingTimeInterval(-behind)
        if let end = heard?.endTime, end > listening {
            idlePolls = 0
            return max(end.timeIntervalSince(listening) + DRAPIConfig.trackUpdateBuffer, 1)
        }

        idlePolls += 1
        let intervals = DRAPIConfig.idleTrackPollingIntervals
        let backoff = intervals[min(idlePolls, intervals.count) - 1]
        guard let next = known.compactMap(\.playedDate).filter({ $0 > listening }).min() else {
            return backoff
        }
        return min(max(next.timeIntervalSince(listening) + 1, 1), backoff)
    }
}
