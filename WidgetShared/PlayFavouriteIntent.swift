//
//  PlayFavouriteIntent.swift
//  WidgetShared
//

#if os(iOS)
import AppIntents

/// A tap on a station in the Favourites widget (F18): plays it, or pauses it if it is the
/// one playing.
///
/// In both targets for the reason `ToggleListeningIntent` is: the system then performs it in
/// the app, with the app's player. A `nonisolated` conformance rather than a `nonisolated`
/// type, as `PlayStationIntent` has: a type with a `@Parameter` cannot be one.
struct PlayFavouriteIntent: nonisolated AudioPlaybackIntent {
    nonisolated static let title: LocalizedStringResource = "Play Station"
    nonisolated static let description = IntentDescription("Plays a DR radio station live.")
    /// The widget's own action; `PlayStationIntent` is the Shortcuts one.
    nonisolated static let isDiscoverable = false

    @Parameter(title: "Station")
    var channelID: String

    nonisolated init() {}

    nonisolated init(channelID: String) {
        self.channelID = channelID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !LYTTER_WIDGETS
        await ListeningSurfaces.playFavourite(channelID)
        #endif
        return .result()
    }
}
#endif
