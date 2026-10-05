//
//  lytterApp.swift
//  lytter
//
//  Created by Emmanuel on 07/08/2025.
//

import SwiftUI

@main
struct lytterApp: App {
    /// The one app-wide DRServiceManager, `DRServiceManager.shared`. Every screen and every
    /// App Intent use this instance. Constructing a second one is expensive: each init() loads the disk cache
    /// and then fetches the whole catalogue, and a successful fetch kicks off an unbounded
    /// preload of every image in the schedule.
    @StateObject private var serviceManager = DRServiceManager.shared
    @StateObject private var deepLinkHandler = DeepLinkHandler()
    /// Joins SharePlay sessions and keeps this device on the session's channel.
    @StateObject private var sharePlay = SharePlayCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    #if os(iOS) || os(tvOS)
    /// Answers Siri's media intent, "Play P3" (F15).
    @UIApplicationDelegateAdaptor(LytterAppDelegate.self) private var appDelegate
    #endif

    #if os(iOS) || os(macOS)
    init() {
        // Before the first scene, so a reminder tapped to launch the app is not missed (F51).
        ReminderNotificationDelegate.shared.install()
    }
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modifier(PreferencesEnvironment(preferences: serviceManager.userPreferences))
                .environmentObject(serviceManager)
                .environmentObject(deepLinkHandler)
                #if os(tvOS)
                // With the app in front, the Siri Remote's Play/Pause button arrives as a
                // press event in the focus hierarchy, not as an MPRemoteCommand, so the
                // command-centre handlers never see it. Unhandled, it fell through to the
                // system, which paused the player but could not bring it back.
                .onPlayPauseCommand {
                    if let channel = serviceManager.playingChannel {
                        serviceManager.togglePlayback(for: channel)
                    }
                }
                #endif
                .onOpenURL { url in
                    deepLinkHandler.handleDeepLink(url)
                }
                #if os(iOS) || os(macOS)
                // A tapped show reminder plays its channel, the way a link does (F51).
                .task {
                    ReminderNotificationDelegate.shared.onOpen = { url in
                        deepLinkHandler.handleDeepLink(url)
                    }
                }
                #endif
                // Without this nothing receives the session an invitation creates, and
                // whoever accepted it hears nothing.
                .task {
                    await sharePlay.observeSessions(serviceManager: serviceManager,
                                                    deepLinkHandler: deepLinkHandler)
                }
                .onChange(of: scenePhase) { _, phase in
                    serviceManager.setAppActive(phase == .active)
                    #if os(iOS) || os(tvOS)
                    // Booked on the way out, so tomorrow's schedule is fetched even if the
                    // app is not opened again before then (F33).
                    if phase == .background { ShowScheduleRefresh.schedule() }
                    #endif
                }
                #if os(macOS)
                .task { ShowScheduleRefresh.start() }
                #endif
                #if os(iOS) || os(macOS)
                // Shortcuts saved before App Intents (F15) carry a "PlayChannelActivity".
                // Nothing donates those any more, but a listener's saved ones should keep
                // working: they go the way a link does, retry and all.
                .onContinueUserActivity("PlayChannelActivity") { activity in
                    if let id = activity.userInfo?["channelId"] as? String,
                       let url = URL(string: "\(DeepLinkHandler.urlScheme):///channel/\(id)") {
                        deepLinkHandler.handleDeepLink(url)
                    }
                }
                #endif
        }
        #if os(iOS) || os(tvOS)
        .backgroundTask(.appRefresh(ShowScheduleRefresh.identifier)) {
            await ShowScheduleRefresh.run()
        }
        #endif

        #if os(macOS)
        Settings {
            macOSSettingsView(preferences: serviceManager.userPreferences)
                .modifier(PreferencesEnvironment(preferences: serviceManager.userPreferences))
        }
        #endif
    }
}
