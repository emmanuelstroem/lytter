//
//  SettingsSections.swift
//  lytter
//

import SwiftUI

/// The settings every platform has (F37, F43), as `Form` sections.
///
/// Each platform puts these in its own container — a pushed `Form` on iOS, a sidebar
/// destination on tvOS, the Settings window on the Mac — and adds what only it has. The
/// choices themselves are the same everywhere, so they are written once.
///
/// Observes `UserPreferencesService` directly; through `DRServiceManager` it would not
/// redraw (see AGENTS.md).
struct SettingsSections: View {
    @ObservedObject var preferences: UserPreferencesService

    @State private var confirmingRemoveFavourites = false
    @State private var confirmingRemoveShows = false
    @State private var confirmingClearHistory = false

    var body: some View {
        Section {
            Toggle("Show Images", isOn: Binding(
                get: { preferences.showsArtwork },
                set: { preferences.setShowsArtwork($0) }))
        } footer: {
            Text("When off, stations show their colour and name instead of programme artwork, which uses less data on a slow connection.")
        }

        #if os(iOS) || os(tvOS)
        Section {
            Picker("Screen Off", selection: Binding(
                get: { preferences.screenOffDelay },
                set: { preferences.setScreenOffDelay($0) })) {
                ForEach(ScreenOffDelay.allCases) { delay in
                    Text(delay.title).tag(delay)
                }
            }
        } footer: {
            #if os(tvOS)
            Text("While something is playing, the screen goes black after this long without a press. The sound carries on, and the next press only brings the screen back.")
            #else
            Text("While something is playing, the screen goes black after this long without a touch. The sound carries on, and the next touch only brings the screen back.")
            #endif
        }
        #endif

        #if os(iOS) || os(macOS)
        ShowRemindersSection(preferences: preferences)
        #endif

        Section {
            LabeledContent("Region") {
                if let region = preferences.preferredDistrict {
                    Text(verbatim: region.name)
                } else {
                    Text("Not Chosen")
                }
            }
            Button("Forget Region", role: .destructive) {
                preferences.rememberDistrict(nil)
            }
            .disabled(preferences.preferredDistrict == nil)
        } footer: {
            Text("Remembered when you choose a district on P4 or P5, and listed first on every regional station.")
        }

        Section {
            Button("Clear Recently Played", role: .destructive) {
                confirmingClearHistory = true
            }
            .disabled(preferences.recentlyPlayed.isEmpty)
            .confirmationDialog("Clear Recently Played?", isPresented: $confirmingClearHistory,
                                titleVisibility: .visible) {
                Button("Clear Recently Played", role: .destructive) {
                    preferences.clearRecentlyPlayed()
                }
            }

            Button("Remove All Favourites", role: .destructive) {
                confirmingRemoveFavourites = true
            }
            .disabled(preferences.favourites.channelIDs.isEmpty)
            .confirmationDialog("Remove All Favourites?", isPresented: $confirmingRemoveFavourites,
                                titleVisibility: .visible) {
                Button("Remove All Favourites", role: .destructive) {
                    preferences.removeAllFavourites()
                }
            } message: {
                Text("Every station you have pinned will be removed from Favourites.")
            }

            Button("Remove All Favourite Shows", role: .destructive) {
                confirmingRemoveShows = true
            }
            .disabled(preferences.favouriteShows.isEmpty)
            .confirmationDialog("Remove All Favourite Shows?", isPresented: $confirmingRemoveShows,
                                titleVisibility: .visible) {
                Button("Remove All Favourite Shows", role: .destructive) {
                    preferences.removeAllFavouriteShows()
                }
            } message: {
                Text("Every show you have pinned will be removed from Shows.")
            }
        } header: {
            Text("Listening")
        }
    }
}

#if os(iOS) || os(macOS)
/// Reminders before favourite shows start (F51). Not on tvOS, which shows no notifications.
///
/// Permission is asked when the toggle is first switched on, not at launch. Refused, the
/// toggle goes back off and the footer says where notifications are turned on.
private struct ShowRemindersSection: View {
    @ObservedObject var preferences: UserPreferencesService
    @Environment(\.openURL) private var openURL
    @State private var isDenied = false

    var body: some View {
        Section {
            Toggle("Remind Me When Shows Start", isOn: Binding(
                get: { preferences.remindsShows },
                set: { switchTo($0) }))
            if isDenied {
                Button("Open Notification Settings") {
                    if let url = Self.notificationSettingsURL { openURL(url) }
                }
            }
        } footer: {
            if isDenied {
                Text("Notifications are turned off for Lytter. Turn them on in Settings to be reminded.")
            } else {
                Text("A notification five minutes before a favourite show starts. When the time comes from the weekly pattern rather than today's schedule, it says so.")
            }
        }
        .task { await refreshDenied() }
    }

    private func switchTo(_ on: Bool) {
        guard on else {
            preferences.setRemindsShows(false)
            return
        }
        preferences.setRemindsShows(true)
        Task {
            let granted = await ShowReminderScheduler.requestAuthorization()
            if !granted { preferences.setRemindsShows(false) }
            await refreshDenied()
        }
    }

    private func refreshDenied() async {
        isDenied = await ShowReminderScheduler.isDenied()
    }

    private static var notificationSettingsURL: URL? {
        #if os(iOS)
        URL(string: UIApplication.openNotificationSettingsURLString)
        #else
        URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
        #endif
    }
}
#endif

extension Bundle {
    /// "1.2 (34)", for the About row.
    var versionDescription: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }
}
