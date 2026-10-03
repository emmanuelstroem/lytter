//
//  iOSSettingsView.swift
//  lytter
//

import SwiftUI

#if os(iOS)
/// The Settings tab.
///
/// A grouped `Form`, as the Settings app and every system app's own settings are, so that
/// it reads as settings at a glance. Siri & Shortcuts lives here: it was a tab of its own,
/// a top-level destination for something set up once and rarely visited again.
struct iOSSettingsView: View {
    @ObservedObject var preferences: UserPreferencesService

    var body: some View {
        NavigationStack {
            Form {
                SettingsSections(preferences: preferences)

                Section {
                    NavigationLink {
                        ShortcutsView()
                    } label: {
                        Label("Siri & Shortcuts", systemImage: "mic.circle")
                    }
                } footer: {
                    Text("Play a station by asking Siri, or from the Shortcuts app.")
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
    iOSSettingsView(preferences: UserPreferencesService())
        .environmentObject(SiriShortcutsService.shared)
        .environmentObject(DRServiceManager())
}
#endif
