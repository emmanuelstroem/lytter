//
//  ConnectionProblem.swift
//  lytter
//

import Foundation

/// What is wrong with the connection, in the terms the listener needs (F42).
///
/// One answer for every screen. Before this, each screen worked it out for itself from
/// `DRServiceManager.error` and `playbackError`: iOS Home, Radio and Search and macOS Home
/// said something, tvOS next to nothing, and the wording was whatever the error's
/// `localizedDescription` happened to be. That could not tell "you are offline" from "DR is
/// not answering", and the two ask different things of the listener: the first is theirs to
/// fix, the second is a wait.
enum ConnectionProblem: Equatable {
    /// The device has no route to the internet.
    case offline
    /// The network works, but DR's API did not answer or answered with an error. `detail`
    /// is the error's own description, for the full-screen state; the 401 message in
    /// `NetworkError` is what tells a developer the API version was retired.
    case drUnavailable(detail: String?)
    /// The catalogue is fine; this channel's stream would not play.
    case streamFailed(channel: String)

    /// The problem to show, most fundamental first.
    ///
    /// Offline explains everything after it — a stream on a dead connection fails too, and
    /// saying "couldn't play P3" would send the listener to the wrong fix. Likewise DR's API
    /// being down outranks one stream failing.
    static func current(isOnline: Bool,
                        catalogueFailure: RequestFailure?,
                        failedStream channel: String?) -> ConnectionProblem? {
        if !isOnline { return .offline }
        switch catalogueFailure {
        case .offline: return .offline
        case .drUnavailable(let detail): return .drUnavailable(detail: detail)
        case nil: break
        }
        if let channel { return .streamFailed(channel: channel) }
        return nil
    }

    /// Whether the problem stops audio, and so belongs in the player as well as over the
    /// channel lists. DR's API being down does not: the stream comes from elsewhere and plays
    /// on; only the programme information stops updating.
    var affectsPlayback: Bool {
        switch self {
        case .offline, .streamFailed: true
        case .drUnavailable: false
        }
    }

    /// Whether the problem is why the channel list could not load. One stream failing is not.
    var concernsCatalogue: Bool {
        switch self {
        case .offline, .drUnavailable: true
        case .streamFailed: false
        }
    }
}

/// Why a request to DR failed, sorted by who can do something about it.
enum RequestFailure: Equatable {
    case offline
    case drUnavailable(detail: String?)

    /// The URL errors that mean this device has no connection, as opposed to DR's end not
    /// answering. A timeout is deliberately not among them: `DRNetworkService` waits for
    /// connectivity, so an offline request does not fail with `.notConnectedToInternet` — it
    /// waits and then times out. Whether that was the device or DR is `NWPathMonitor`'s to
    /// say, and `ConnectionProblem.current` asks it first.
    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
        .internationalRoamingOff, .callIsActive
    ]

    init(_ error: Error) {
        if let urlError = error as? URLError, Self.offlineCodes.contains(urlError.code) {
            self = .offline
        } else {
            self = .drUnavailable(detail: error.localizedDescription)
        }
    }
}

/// How long DR has to answer before the loading state says it is still waiting, and how
/// long to leave between automatic retries while it is not answering.
enum ConnectionTiming {
    /// The tvOS launch cover lifts at 5 s (F34); a viewer looking at a spinner after that
    /// should be told it is DR that is slow, not the app that is stuck.
    static let slowAfter: Duration = .seconds(6)

    /// Retry `attempt` (0-based) waits this long: 15 s, 30 s, 60 s, then every 2 minutes.
    /// Short enough that a blip is over without the listener noticing much; capped so an
    /// outage of an hour is not a request every few seconds from every TV left on.
    static func retryDelay(afterAttempt attempt: Int) -> Duration {
        .seconds(min(15 * (1 << min(attempt, 3)), 120))
    }
}

/// What a channel-list screen shows in place of its channels, when it has none to show.
enum CatalogueState: Equatable {
    case content
    case loading(isSlow: Bool)
    case problem(ConnectionProblem)
    case empty

    /// A known problem outranks a fetch in flight. Offline, the fetch is only waiting for a
    /// connection that may be minutes away; with DR down, it is an automatic retry that will
    /// most likely fail the same way — and a spinner each time it ran made the screen flicker
    /// between "loading" and "DR isn't answering" on every attempt.
    static func current(hasChannels: Bool, isLoading: Bool, isWaitingLong: Bool,
                        problem: ConnectionProblem?) -> CatalogueState {
        if hasChannels { return .content }
        if let problem, problem.concernsCatalogue { return .problem(problem) }
        return isLoading ? .loading(isSlow: isWaitingLong) : .empty
    }
}

extension ConnectionProblem {
    /// The problem behind one failed request, for a screen that fetches for itself — the
    /// schedule sheets — rather than through the catalogue.
    static func forFailedRequest(_ error: Error, isOnline: Bool) -> ConnectionProblem {
        current(isOnline: isOnline, catalogueFailure: RequestFailure(error), failedStream: nil)
            ?? .drUnavailable(detail: error.localizedDescription)
    }
}
