//
//  PlayMediaIntentHandler.swift
//  lytter
//

#if os(iOS) || os(tvOS)
import Intents
import UIKit

/// "Play P3", with no app name, on iPhone and Apple TV (F15).
///
/// App Shortcuts must name the app in every phrase. SiriKit's media intent does not: it is
/// how a radio app joins the system's own "play …" grammar, and once someone has used it
/// Siri learns that Lytter is where they listen to the radio. On Apple TV it is the whole
/// of Siri support — App Shortcuts are not known to run there.
///
/// Handled in the app rather than in an Intents extension: an extension lives too briefly
/// to play audio, and Apple's advice for media is to hand playback to the app anyway.
/// `LytterAppDelegate` returns this for `INPlayMediaIntent`.
final class PlayMediaIntentHandler: NSObject, INPlayMediaIntentHandling {

    /// Which channel was meant. "Play P4" is the listener's own district when they have
    /// one (`StationLookup`); a request with no name — "play the radio in Lytter" — is
    /// the station last played.
    @MainActor
    func resolveMediaItems(for intent: INPlayMediaIntent) async -> [INPlayMediaMediaItemResolutionResult] {
        let manager = DRServiceManager.shared
        let channels = await StationCatalogue.channels()

        guard let name = intent.mediaSearch?.mediaName, !name.isEmpty else {
            guard let last = manager.playingChannel
                    ?? manager.userPreferences.findLastPlayedChannel(in: channels) else {
                return [.unsupported()]
            }
            return [.success(with: Self.mediaItem(for: last))]
        }

        let matches = StationLookup.channels(answering: name, in: channels,
                                             region: manager.userPreferences.preferredDistrict)
        switch matches.count {
        case 0: return [.unsupported()]
        case 1: return [.success(with: Self.mediaItem(for: matches[0]))]
        default: return [.disambiguation(with: matches.map(Self.mediaItem(for:)))]
        }
    }

    @MainActor
    func handle(intent: INPlayMediaIntent) async -> INPlayMediaIntentResponse {
        let channels = await StationCatalogue.channels()
        guard let id = intent.mediaItems?.first?.identifier,
              let channel = channels.first(where: { $0.id == id }) else {
            return INPlayMediaIntentResponse(code: .failure, userActivity: nil)
        }
        DRServiceManager.shared.playChannel(channel)
        return INPlayMediaIntentResponse(code: .success, userActivity: nil)
    }

    @MainActor
    private static func mediaItem(for channel: DRChannel) -> INMediaItem {
        INMediaItem(identifier: channel.id, title: channel.qualifiedName,
                    type: .radioStation, artwork: nil)
    }
}

/// Hands Siri's media intent to `PlayMediaIntentHandler`. The app has no other use for an
/// app delegate.
final class LytterAppDelegate: NSObject, UIApplicationDelegate {
    private let playMedia = PlayMediaIntentHandler()

    func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        intent is INPlayMediaIntent ? playMedia : nil
    }
}
#endif
