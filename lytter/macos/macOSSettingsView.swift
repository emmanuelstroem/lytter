//
//  macOSSettingsView.swift
//  lytter
//

import SwiftUI

#if os(macOS)
/// The Settings window, from the app menu or ⌘, — where a Mac app's settings go, rather
/// than a destination in the sidebar.
///
/// Screen Off is not here: a Mac has its own display sleep, and no one leaves a laptop on a
/// stand as a radio.
struct macOSSettingsView: View {
    @ObservedObject var preferences: UserPreferencesService

    var body: some View {
        Form {
            SettingsSections(preferences: preferences)
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
#endif
