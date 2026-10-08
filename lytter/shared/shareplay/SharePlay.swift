//
//  SharePlay.swift
//  lytter
//
//  Listening together, shared by every platform that offers it.
//
//  What used to be here was half a feature. tvOS activated an activity, and nothing in the
//  app ever asked for the sessions that activation creates — so the other side of a
//  FaceTime call was offered "Listen together", accepted, and heard nothing. The app had
//  no `com.apple.developer.group-session` entitlement either, without which the system
//  will not hand it a session at all, and the activity called itself `.watchTogether`.
//
//  The pieces now:
//
//    - `RadioShareActivity`, the activity: which channel, and what the call shows for it.
//    - `SharePlayCoordinator`, the side that was missing: it receives sessions, plays the
//      session's channel, and moves the session along when this listener changes channel.
//    - `SharePlayFollow`, the one decision worth testing on its own: when a local channel
//      change should become everyone's.
//    - `SharedChannel` (iOS, macOS), what the share sheet is handed, so SharePlay appears
//      there the way it does in Music. tvOS has no share sheet; it has a button.
//

import Foundation
import Combine
import os
#if canImport(GroupActivities)
import GroupActivities
#endif
#if os(iOS) || os(macOS) || os(visionOS)
import CoreTransferable
#endif

#if canImport(GroupActivities)
/// The SharePlay activity for listening together.
///
/// `nonisolated`: under the project's main-actor default its `GroupActivity` conformance
/// would be main-actor isolated, and `activate()` and `sessions()` cross into concurrent
/// contexts. Swift 6 rejects an isolated conformance there.
nonisolated struct RadioShareActivity: GroupActivity, Equatable {
    static let activityIdentifier = "com.eopio.lytter.shareplay.radio"

    /// `DRChannel.id`. Resolved on the receiving side through the same lookup a link uses,
    /// so a slug would work as well.
    let channelId: String
    let channelTitle: String
    /// DR's own page for the channel, for someone on the call who does not have the app.
    let webPageURL: String?

    init(channelId: String, channelTitle: String, webPageURL: String? = nil) {
        self.channelId = channelId
        self.channelTitle = channelTitle
        self.webPageURL = webPageURL
    }

    @MainActor
    init(channel: DRChannel) {
        self.init(channelId: channel.id, channelTitle: channel.title,
                  webPageURL: channel.presentationUrl)
    }

    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = channelTitle
        // Radio is listened to. `.watchTogether` made the call describe it as video.
        metadata.type = .listenTogether
        metadata.fallbackURL = webPageURL.flatMap(URL.init(string:))
        return metadata
    }
}
#endif

/// When a channel change on this device should move the whole session.
///
/// Joining a session must not overwrite it: a listener who joins while playing P3 is
/// playing P3 only until the session's channel loads, and publishing P3 in that moment
/// would drag everyone else away from what they were invited to. So a local change is
/// published only once this device has caught up with the session — has played the
/// channel the session names — and after that every local change is everyone's.
nonisolated struct SharePlayFollow: Equatable {
    private(set) var sessionChannelId: String?
    private(set) var caughtUp = false

    /// The session named a channel, ours or someone else's. Returns whether this device
    /// still has to tune to it.
    mutating func sessionChanged(to channelId: String, localChannelId: String?) -> Bool {
        sessionChannelId = channelId
        caughtUp = localChannelId == channelId
        return !caughtUp
    }

    /// This device started playing a channel. Returns whether the session should follow.
    mutating func localChanged(to channelId: String) -> Bool {
        guard let sessionChannelId else { return false }
        if channelId == sessionChannelId {
            caughtUp = true
            return false
        }
        return caughtUp
    }
}

#if canImport(GroupActivities)
/// Receives SharePlay sessions and keeps this device and the session on the same channel.
///
/// Incoming channels go through `DeepLinkHandler`, as if the listener had opened a link to
/// them. That is the path every platform already resolves, selects and navigates for —
/// tvOS moves to Now Playing, iOS selects the channel — so SharePlay needs no per-screen
/// code. It waits for the catalogue first: a session that launches the app arrives before
/// the channels do, and tvOS drops a link it cannot resolve.
///
/// Pause stays personal. This is live radio: there is nothing to keep in step but the
/// channel, and pausing everyone's stream because one person took a phone call is not
/// what listening together on the radio means.
@MainActor
final class SharePlayCoordinator: ObservableObject {
    private var session: GroupSession<RadioShareActivity>?
    private var follow = SharePlayFollow()
    private var subscriptions = Set<AnyCancellable>()

    /// Runs for the life of the app. Call once, from the root view's `.task`.
    func observeSessions(serviceManager: DRServiceManager,
                         deepLinkHandler: DeepLinkHandler) async {
        for await session in RadioShareActivity.sessions() {
            join(session, serviceManager: serviceManager, deepLinkHandler: deepLinkHandler)
        }
    }

    /// Starts listening together on `channel`, if a FaceTime call is there to carry it.
    ///
    /// On iOS and macOS the share sheet is the way in (`SharedChannel`); this is for tvOS,
    /// which has no share sheet and shows a button instead.
    static func start(_ channel: DRChannel) async {
        let activity = RadioShareActivity(channel: channel)
        switch await activity.prepareForActivation() {
        case .activationPreferred:
            do {
                _ = try await activity.activate()
            } catch {
                Log.playback.error(
                    "SharePlay activation failed: \(error.localizedDescription, privacy: .public)")
            }
        case .activationDisabled:
            Log.playback.info("SharePlay is turned off for this activity")
        case .cancelled:
            break
        @unknown default:
            break
        }
    }

    private func join(_ newSession: GroupSession<RadioShareActivity>,
                      serviceManager: DRServiceManager,
                      deepLinkHandler: DeepLinkHandler) {
        leave()
        session = newSession
        Log.playback.info("joined a SharePlay session")

        newSession.$activity
            .removeDuplicates { $0.channelId == $1.channelId }
            .sink { [weak self] activity in
                guard let self else { return }
                let mustTune = follow.sessionChanged(
                    to: activity.channelId,
                    localChannelId: serviceManager.playingChannel?.id)
                guard mustTune else { return }
                tune(to: activity.channelId, serviceManager: serviceManager,
                     deepLinkHandler: deepLinkHandler)
            }
            .store(in: &subscriptions)

        serviceManager.$playingChannel
            .compactMap { $0 }
            .removeDuplicates { $0.id == $1.id }
            .sink { [weak self, weak newSession] channel in
                guard let self, let newSession else { return }
                guard follow.localChanged(to: channel.id) else { return }
                Log.playback.debug("moving the SharePlay session to \(channel.slug, privacy: .public)")
                newSession.activity = RadioShareActivity(channel: channel)
            }
            .store(in: &subscriptions)

        newSession.$state
            .sink { [weak self, weak newSession] state in
                guard case .invalidated = state, let self, self.session === newSession
                else { return }
                Log.playback.info("the SharePlay session ended")
                leave()
            }
            .store(in: &subscriptions)

        newSession.join()
    }

    private func leave() {
        subscriptions.removeAll()
        session = nil
        follow = SharePlayFollow()
    }

    /// Hands the channel to the deep-link path once there is a catalogue to find it in.
    /// The wait belongs to the session: if it ends first, nothing is tuned.
    private func tune(to channelId: String, serviceManager: DRServiceManager,
                      deepLinkHandler: DeepLinkHandler) {
        guard let url = Self.deepLinkURL(forChannelId: channelId) else { return }
        serviceManager.$availableChannels
            .first { !$0.isEmpty }
            .sink { _ in deepLinkHandler.handleDeepLink(url) }
            .store(in: &subscriptions)
    }

    /// The link a channel's own share button would produce.
    static func deepLinkURL(forChannelId channelId: String) -> URL? {
        URL(string: "\(DeepLinkHandler.urlScheme):///channel/\(channelId)")
    }
}
#endif

#if os(iOS) || os(macOS) || os(visionOS)
/// What the player's share button shares.
///
/// Handing the share sheet a `GroupActivityTransferRepresentation` is what puts SharePlay
/// in it — at the top of the iOS sheet, in the Mac's share menu, the way Music does it —
/// and from there into a FaceTime call or Messages. The text is everything else: Messages, Mail, Notes, copy.
nonisolated struct SharedChannel: Transferable {
    let activity: RadioShareActivity
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        GroupActivityTransferRepresentation { shared in shared.activity }
        ProxyRepresentation(exporting: \.text)
    }
}
#endif
