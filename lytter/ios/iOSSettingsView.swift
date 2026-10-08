//
//  iOSSettingsView.swift
//  lytter
//

import AppIntents
import SwiftUI

#if os(iOS) || os(visionOS)
/// The Settings tab.
///
/// A grouped `Form`, as the Settings app and every system app's own settings are, so that
/// it reads as settings at a glance. Siri & Shortcuts lives here: it was a tab of its own,
/// a top-level destination for something set up once and rarely visited again.
///
/// Since F15 the App Shortcuts work as soon as the app is installed; the name-free "Play
/// P3" (the SiriKit media intent) needs Siri's permission, which `SiriAccessRow` asks for.
/// The section says what to say, and links to the app's shortcuts with the system's button.
struct iOSSettingsView: View {
    @ObservedObject var preferences: UserPreferencesService
    let channels: [DRChannel]

    var body: some View {
        NavigationStack {
            Form {
                SettingsSections(preferences: preferences, channels: channels)

                Section {
                    SiriAccessRow()
                    #if os(iOS)
                    // Not on visionOS: the button is drawn by another process, and the
                    // Form's scrolling does not clip it there — scrolled out of view, it
                    // went on showing below the window's bottom edge.
                    ShortcutsLink()
                        .shortcutsLinkStyle(.automaticOutline)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    #endif
                } header: {
                    Text("Siri & Shortcuts")
                } footer: {
                    Text("Say “Play P3” — Siri learns that Lytter is where you listen to the radio. With the app's name there is more: “Stop Lytter in 30 minutes”, “Stop Lytter after this programme”, “What's on Lytter?”. The same actions are in the Shortcuts app.")
                }

                Section {
                    LabeledContent("Version") {
                        Text(verbatim: Bundle.main.versionDescription)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            // Room for the mini player, as on the other tabs.
            .contentMargins(.bottom, 100, for: .scrollContent)
        }
    }
}

#Preview {
    iOSSettingsView(preferences: UserPreferencesService(), channels: [])
}
#endif
