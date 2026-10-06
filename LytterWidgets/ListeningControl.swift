//
//  ListeningControl.swift
//  LytterWidgets
//

import AppIntents
import SwiftUI
import WidgetKit

/// Play/pause in Control Centre, on the Lock Screen and on the Action Button (F18), from
/// iOS 18.
@available(iOS 18.0, *)
struct ListeningControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: NowPlayingStore.controlKind,
                                   provider: ListeningControlProvider()) { value in
            ControlWidgetButton(action: ToggleListeningIntent()) {
                // The station's own name: a proper noun, not for the catalogue.
                Label {
                    if let station = value.station {
                        Text(verbatim: station)
                    } else {
                        Text(verbatim: "Lytter")
                    }
                } icon: {
                    Image(systemName: value.isPlaying ? "pause.fill" : "play.fill")
                }
            }
        }
        .displayName("Play or Pause")
        .description("Plays or pauses the station you last listened to.")
    }
}

@available(iOS 18.0, *)
struct ListeningControlProvider: ControlValueProvider {
    struct Value: Sendable {
        let isPlaying: Bool
        let station: String?
    }

    var previewValue: Value { Value(isPlaying: false, station: nil) }

    func currentValue() async throws -> Value {
        let snapshot = NowPlayingStore().load()
        return Value(isPlaying: snapshot?.isPlaying ?? false, station: snapshot?.channelName)
    }
}
