//
//  tvOSSettingsView.swift
//  lytter
//

import SwiftUI

#if os(tvOS)
/// The Settings destination, at the bottom of the sidebar (F37).
///
/// A `Form` scrolls on tvOS because every row in it can take focus; it is listed in
/// `TVScrollingCoverageTests` against `testSettingsScrolls`, and the list the Region
/// picker pushes against `testRegionPickerScrolls`.
struct tvOSSettingsView: View {
    @ObservedObject var preferences: UserPreferencesService
    let channels: [DRChannel]

    var body: some View {
        NavigationStack {
            Form {
                SettingsSections(preferences: preferences, channels: channels)

                Section {
                    SiriAccessRow()
                } header: {
                    Text("Siri")
                } footer: {
                    Text("Hold the Siri button on the remote and say “Play P3”.")
                }

                Section {
                    LabeledContent("Version") {
                        Text(verbatim: Bundle.main.versionDescription)
                    }
                    // A row that cannot take focus is a row the list cannot scroll to.
                    .focusable()
                }
            }
            .navigationTitle("Settings")
        }
    }
}
#endif
