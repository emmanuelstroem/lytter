//
//  SiriAccessRow.swift
//  lytter
//

#if os(iOS) || os(tvOS)
import Intents
import SwiftUI

/// Whether Siri may play stations, and the button that asks (F15).
///
/// SiriKit's media intent — the name-free "Play P3" — needs the listener's permission. It
/// is asked for here, when someone has come to Settings to set Siri up, rather than at
/// launch, where a permission prompt has no context. App Shortcuts need none.
struct SiriAccessRow: View {
    @State private var status = INPreferences.siriAuthorizationStatus()

    var body: some View {
        switch status {
        case .notDetermined:
            Button("Allow Siri to Play Stations") {
                Task {
                    status = await withCheckedContinuation { continuation in
                        INPreferences.requestSiriAuthorization { continuation.resume(returning: $0) }
                    }
                }
            }
        case .authorized:
            Label("Siri can play stations", systemImage: "checkmark.circle")
        default:
            Text("Siri is turned off for Lytter. Turn it on in the Settings app, under Siri.")
                .foregroundStyle(Color.secondary)
        }
    }
}
#endif
