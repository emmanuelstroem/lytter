//
//  ConnectionProblemTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// What the app tells the listener about the connection (F42): which problem, in what
/// order, and what a channel list shows in place of its channels.
@MainActor
struct ConnectionProblemTests {

    private let drDown = RequestFailure.drUnavailable(detail: "DR server error (503).")

    // MARK: - Which problem

    @Test func nothingWrongIsNothingToSay() {
        #expect(ConnectionProblem.current(isOnline: true, catalogueFailure: nil,
                                          failedStream: nil) == nil)
    }

    /// The path monitor is the authority: offline requests wait and then time out, which on
    /// its own reads exactly like DR not answering.
    @Test func offlineOutranksADRFailure() {
        #expect(ConnectionProblem.current(isOnline: false, catalogueFailure: drDown,
                                          failedStream: "P3") == .offline)
    }

    /// A stream failing on a dead connection is the connection's fault, and saying
    /// "couldn't play P3" would send the listener to the wrong fix.
    @Test func offlineOutranksAStreamFailure() {
        #expect(ConnectionProblem.current(isOnline: false, catalogueFailure: nil,
                                          failedStream: "P3") == .offline)
    }

    @Test func drDownOutranksAStreamFailure() {
        #expect(ConnectionProblem.current(isOnline: true, catalogueFailure: drDown,
                                          failedStream: "P3")
                == .drUnavailable(detail: "DR server error (503)."))
    }

    @Test func aStreamFailureAloneNamesTheChannel() {
        #expect(ConnectionProblem.current(isOnline: true, catalogueFailure: nil,
                                          failedStream: "P3") == .streamFailed(channel: "P3"))
    }

    /// A request can know it is offline before the path monitor has said so.
    @Test func aRequestThatSaysOfflineIsOfflineEvenIfThePathHasNotCaughtUp() {
        #expect(ConnectionProblem.current(isOnline: true, catalogueFailure: .offline,
                                          failedStream: nil) == .offline)
    }

    // MARK: - Sorting errors

    @Test func noConnectionErrorsAreOffline() {
        for code in [URLError.Code.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed] {
            #expect(RequestFailure(URLError(code)) == .offline, "\(code)")
        }
    }

    /// Not offline: with `waitsForConnectivity`, an offline request times out too, so a
    /// timeout says nothing about whose end it was. The path monitor decides.
    @Test func aTimeoutIsNotTakenAsOffline() {
        guard case .drUnavailable = RequestFailure(URLError(.timedOut)) else {
            Issue.record("a timeout was sorted as offline")
            return
        }
    }

    @Test func serverAndHostErrorsAreDRs() {
        let errors: [Error] = [NetworkError.httpError(503), NetworkError.decodingError,
                               URLError(.cannotConnectToHost), URLError(.cannotFindHost)]
        for error in errors {
            guard case .drUnavailable = RequestFailure(error) else {
                Issue.record("\(error) was not put down to DR")
                continue
            }
        }
    }

    /// The 401 text is what tells a developer the API version was retired; keep it.
    @Test func drFailuresKeepTheErrorsOwnWords() {
        #expect(RequestFailure(NetworkError.httpError(401))
                == .drUnavailable(detail: NetworkError.httpError(401).localizedDescription))
    }

    // MARK: - Where it is shown

    /// The player shows only what stops audio. DR's API being down does not: the stream
    /// comes from elsewhere and plays on.
    @Test func onlyOfflineAndStreamFailuresConcernThePlayer() {
        #expect(ConnectionProblem.offline.affectsPlayback)
        #expect(ConnectionProblem.streamFailed(channel: "P1").affectsPlayback)
        #expect(!ConnectionProblem.drUnavailable(detail: nil).affectsPlayback)
    }

    // MARK: - In place of the channels

    @Test func channelsOnScreenAreShownWhateverIsWrong() {
        for problem: ConnectionProblem? in [nil, .offline, .drUnavailable(detail: nil)] {
            #expect(CatalogueState.current(hasChannels: true, isLoading: true,
                                           isWaitingLong: true, problem: problem) == .content)
        }
    }

    /// Offline, the fetch is only waiting for a connection; a spinner would say otherwise.
    @Test func offlineWithNothingCachedSaysOfflineNotLoading() {
        #expect(CatalogueState.current(hasChannels: false, isLoading: true,
                                       isWaitingLong: false, problem: .offline)
                == .problem(.offline))
    }

    /// An automatic retry while DR is down must not flash a spinner on every attempt.
    @Test func aRetryUnderwayKeepsSayingDRIsNotAnswering() {
        #expect(CatalogueState.current(hasChannels: false, isLoading: true,
                                       isWaitingLong: false,
                                       problem: .drUnavailable(detail: nil))
                == .problem(.drUnavailable(detail: nil)))
    }

    @Test func aSlowFirstLoadSaysItIsStillWaiting() {
        #expect(CatalogueState.current(hasChannels: false, isLoading: true,
                                       isWaitingLong: false, problem: nil)
                == .loading(isSlow: false))
        #expect(CatalogueState.current(hasChannels: false, isLoading: true,
                                       isWaitingLong: true, problem: nil)
                == .loading(isSlow: true))
    }

    /// One stream failing is not why there are no channels.
    @Test func aStreamFailureIsNotACatalogueState() {
        #expect(CatalogueState.current(hasChannels: false, isLoading: false,
                                       isWaitingLong: false, problem: .streamFailed(channel: "P1"))
                == .empty)
    }

    // MARK: - Retrying

    @Test func retriesWidenAndThenSettle() {
        let delays = (0..<6).map { ConnectionTiming.retryDelay(afterAttempt: $0) }
        #expect(delays == [.seconds(15), .seconds(30), .seconds(60), .seconds(120),
                           .seconds(120), .seconds(120)])
    }

    /// The tvOS launch cover lifts at 5 s (F34); "still waiting" should be said after it.
    @Test func stillWaitingComesAfterTheTVLaunchHold() {
        #expect(ConnectionTiming.slowAfter > .seconds(5))
    }
}
