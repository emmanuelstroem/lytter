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
    /// The channels on offer, for the regions they broadcast (F50).
    let channels: [DRChannel]

    @State private var confirmingRemoveFavourites = false
    @State private var confirmingRemoveShows = false
    @State private var confirmingClearHistory = false

    private var regions: [District] {
        District.choices(in: channels, keeping: preferences.preferredDistrict)
    }

    var body: some View {
        // Nothing to choose between until there are two.
        if BroadcasterRegistry.broadcasters.count > 1 {
            BroadcastersSection(preferences: preferences)
        }

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
            // Tagged by id, not by `District`: a stored name DR has since restyled is the
            // same region, but not an equal value, and would leave the picker unselected.
            Picker("Region", selection: Binding(
                get: { preferences.preferredDistrict?.id },
                set: { id in
                    preferences.rememberDistrict(regions.first { $0.id == id })
                })) {
                Text("Not Chosen").tag(String?.none)
                ForEach(regions) { region in
                    Text(verbatim: region.name).tag(Optional(region.id))
                }
            }
        } footer: {
            Text("Shown on the P4 and P5 cards, and listed first when you choose a district. A region only one of them broadcasts leaves the other as it was.")
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

/// Which broadcasters are shown, and in what order (F54b).
///
/// A toggle each, everywhere. Reordering is by dragging — touch and hold on iOS, where no
/// Edit button is needed for one short list; on tvOS, where a row cannot be dragged with
/// the remote, the order is only shown. The last broadcaster
/// shown cannot be switched off.
private struct BroadcastersSection: View {
    @ObservedObject var preferences: UserPreferencesService

    var body: some View {
        let arranged = preferences.arrangedBroadcasters
        let shownCount = preferences.visibleBroadcasters.count

        Section {
            ForEach(arranged) { broadcaster in
                // What is on screen, not what is stored: should the stored ids hide them
                // all, the one shown anyway reads on.
                let isShown = preferences.isShown(broadcaster.id)
                Toggle(isOn: Binding(
                    get: { isShown },
                    set: { preferences.setBroadcaster(broadcaster.id, shown: $0) })) {
                    Text(verbatim: broadcaster.name)
                }
                .disabled(isShown && shownCount == 1)
            }
            #if !os(tvOS)
            .onMove { offsets, destination in
                var ids = arranged.map(\.id)
                ids.move(fromOffsets: offsets, toOffset: destination)
                preferences.setBroadcasterOrder(ids)
            }
            #endif
        } header: {
            Text("Broadcasters")
        } footer: {
            #if os(iOS)
            Text("Touch and hold one to drag it to a new place on Home. A broadcaster switched off is left out of Home, Search, CarPlay and the Favourites widget; your favourites from it are kept for when it is switched back on.")
            #elseif os(macOS)
            Text("Drag to reorder them on Home. A broadcaster switched off is left out of Home and Search; your favourites from it are kept for when it is switched back on.")
            #else
            Text("A broadcaster switched off is left out of Home and Search; your favourites from it are kept for when it is switched back on.")
            #endif
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
