//
//  PlaybackIntents.swift
//  lytter
//

#if os(iOS) || os(visionOS)
import AppIntents

// The App Intents (F15), on iPhone. Each phrase has to name the app — App Shortcuts
// require it — so they read "Pause Lytter". Playing a station by name is the SiriKit media
// intent instead (`PlayMediaIntentHandler`, iPhone and Apple TV): "Play P3", with or without
// "in Lytter".
//
// No App Shortcut takes a station. iOS 26 collapses an App Shortcut whose parameter is an
// entity into one tile in the Shortcuts app and one row in Spotlight, captioned with the
// last value and running the first: "P8" that played P1. A textbook two-value entity does
// the same, so it is the system, not this code. `PlayStationIntent` and the station
// parameter of `WhatsOnIntent` are still actions in the Shortcuts app, where the station is
// picked from a list.
//
// Every conformance here is `nonisolated`, against the project's MainActor default. Left
// to the default, Swift 6.2 infers main-actor conformances, which cannot be used off the
// main actor — and AppIntents looks these types up from a background thread. What touches
// the app is marked `@MainActor` instead.

/// Plays a station. An `AudioPlaybackIntent`, so the system lets it start audio without
/// bringing the app to the front.
struct PlayStationIntent: nonisolated AudioPlaybackIntent {
    nonisolated static let title: LocalizedStringResource = "Play Station"
    nonisolated static let description = IntentDescription("Plays a DR radio station live.")

    @Parameter(title: "Station")
    var station: StationEntity

    nonisolated init() {}

    nonisolated init(station: StationEntity) {
        self.station = station
    }

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Play \(\.$station)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let channels = await StationCatalogue.channels()
        guard let channel = channels.first(where: { $0.id == station.id }) else {
            throw PlaybackIntentError.stationNotFound
        }
        DRServiceManager.shared.playChannel(channel)
        return .result(dialog: "Playing \(station.name)")
    }
}

/// Picks up where the listener left off: the paused station, or the last one played.
nonisolated struct ResumePlaybackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Resume Listening"
    static let description = IntentDescription("Plays the station you last listened to.")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = DRServiceManager.shared
        let channels = await StationCatalogue.channels()
        guard let channel = manager.playingChannel
                ?? manager.userPreferences.findLastPlayedChannel(in: channels) else {
            throw PlaybackIntentError.nothingToResume
        }
        if !manager.isAudible(channel) {
            manager.togglePlayback(for: channel)
        }
        return .result(dialog: "Playing \(channel.qualifiedName)")
    }
}

/// Pauses whatever is playing. Nothing playing is not an error: the request is met.
nonisolated struct PausePlaybackIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause"
    static let description = IntentDescription("Pauses the radio.")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        let manager = DRServiceManager.shared
        if let channel = manager.playingChannel, manager.isAudible(channel) {
            manager.togglePlayback(for: channel)
        }
        return .result()
    }
}

/// The sleep timer's own choices, as something a phrase can name. App Shortcut phrases
/// take entities and enums, not free numbers, so "in 20 minutes" is not one of them.
nonisolated enum SleepTimerDuration: Int, AppEnum {
    case fifteen = 15
    case thirty = 30
    case fortyFive = 45
    case sixty = 60

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Duration")
    static let caseDisplayRepresentations: [SleepTimerDuration: DisplayRepresentation] = [
        .fifteen: "15 minutes",
        .thirty: "30 minutes",
        .fortyFive: "45 minutes",
        .sixty: "60 minutes"
    ]
}

/// "Stop Lytter in 30 minutes": the sleep timer, fade and all.
struct SleepTimerIntent: nonisolated AppIntent {
    nonisolated static let title: LocalizedStringResource = "Set Sleep Timer"
    nonisolated static let description = IntentDescription("Stops the radio after a while, fading out first.")

    @Parameter(title: "Duration", default: .thirty)
    var duration: SleepTimerDuration

    nonisolated init() {}

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Stop in \(\.$duration)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try startSleepTimer(.after(minutes: duration.rawValue))
        return .result(dialog: "Stopping in \(duration.rawValue) minutes")
    }
}

/// "Stop Lytter after this programme".
nonisolated struct StopAfterProgrammeIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop After This Programme"
    static let description = IntentDescription("Stops the radio when the programme on air ends.")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try startSleepTimer(.endOfProgramme)
        return .result(dialog: "Stopping when this programme ends")
    }
}

/// Starts the sleep timer, or says why it cannot.
@MainActor
private func startSleepTimer(_ mode: SleepTimerMode) throws {
    let manager = DRServiceManager.shared
    guard let channel = manager.playingChannel, manager.isAudible(channel) else {
        throw PlaybackIntentError.nothingPlaying
    }
    guard manager.startSleepTimer(mode) else {
        // Only end-of-programme can fail with something playing: no schedule to end.
        throw PlaybackIntentError.noProgrammeEnd
    }
}

/// "What's on Lytter?" — the programme on the station playing, or last played. Answers
/// without playing anything. In the Shortcuts app a station can be picked instead.
struct WhatsOnIntent: nonisolated AppIntent {
    nonisolated static let title: LocalizedStringResource = "What's On"
    nonisolated static let description = IntentDescription("Says which programme is on a station now.")

    @Parameter(title: "Station")
    var station: StationEntity?

    nonisolated init() {}

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("What's on \(\.$station)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = DRServiceManager.shared
        let channels = await StationCatalogue.channels()
        let chosen = station.flatMap { station in channels.first { $0.id == station.id } }
        guard let channel = chosen ?? manager.playingChannel
                ?? manager.userPreferences.findLastPlayedChannel(in: channels) else {
            throw station == nil ? PlaybackIntentError.nothingToResume : .stationNotFound
        }
        let name = channel.qualifiedName
        guard let programme = manager.getCurrentProgram(for: channel) else {
            return .result(dialog: "DR hasn't said what's on \(name) right now.")
        }
        guard let end = programme.endDate else {
            return .result(dialog: "On \(name) now: \(programme.programmeName).")
        }
        let until = end.formatted(date: .omitted, time: .shortened)
        return .result(dialog: "On \(name) now: \(programme.programmeName), until \(until).")
    }
}

enum PlaybackIntentError: Error, CustomLocalizedStringResourceConvertible {
    case stationNotFound
    case nothingToResume
    case nothingPlaying
    case noProgrammeEnd

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .stationNotFound: "That station isn't on DR's list right now."
        case .nothingToResume: "Nothing has been played yet. Ask for a station by name."
        case .nothingPlaying: "Nothing is playing."
        case .noProgrammeEnd: "DR hasn't said when this programme ends."
        }
    }
}

/// The phrases Siri knows without any setup, and the tiles in the Shortcuts app. None takes
/// a station — see the note at the top of this file.
///
/// Danish phrases are in `AppShortcuts.xcstrings`, the catalog App Shortcuts are read from.
nonisolated struct LytterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ResumePlaybackIntent(),
            phrases: [
                "Play \(.applicationName)",
                "Resume \(.applicationName)"
            ],
            shortTitle: "Resume Listening",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: PausePlaybackIntent(),
            phrases: [
                "Pause \(.applicationName)",
                "Stop \(.applicationName)"
            ],
            shortTitle: "Pause",
            systemImageName: "pause.fill"
        )
        AppShortcut(
            intent: SleepTimerIntent(),
            phrases: [
                "Stop \(.applicationName) in \(\.$duration)",
                "Turn off \(.applicationName) in \(\.$duration)"
            ],
            shortTitle: "Sleep Timer",
            systemImageName: "moon.zzz"
        )
        AppShortcut(
            intent: StopAfterProgrammeIntent(),
            phrases: [
                "Stop \(.applicationName) after this programme",
                "Stop \(.applicationName) after this program"
            ],
            shortTitle: "Stop After This Programme",
            systemImageName: "moon"
        )
        AppShortcut(
            intent: WhatsOnIntent(),
            phrases: [
                "What's on \(.applicationName)",
                "What's playing on \(.applicationName)"
            ],
            shortTitle: "What's On",
            systemImageName: "list.bullet"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .purple
}
#endif
