//
//  ToggleListeningIntent.swift
//  WidgetShared
//

#if os(iOS)
import AppIntents

/// Play/pause from a widget or the Control Centre control (F18).
///
/// Compiled into the app and the widget extension both, which is what makes the system run
/// it in the app: an `AudioPlaybackIntent` that the app also contains is performed there,
/// with the app's player, rather than in the extension, which has none. The extension's
/// copy is never performed; `LYTTER_WIDGETS` keeps the app's types out of it.
///
/// `nonisolated`, as every intent in the app is — see `PlaybackIntents.swift`.
nonisolated struct ToggleListeningIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play or Pause"
    static let description = IntentDescription("Plays or pauses the station you last listened to.")
    /// Not offered as a Shortcuts action: the app's own Resume and Pause are those.
    static let isDiscoverable = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !LYTTER_WIDGETS
        await ListeningSurfaces.toggleListening()
        #endif
        return .result()
    }
}
#endif
