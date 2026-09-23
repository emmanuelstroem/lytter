//
//  lytterApp.swift
//  lytter
//
//  Created by Emmanuel on 07/08/2025.
//

import SwiftUI

@main
struct lytterApp: App {
    /// The one app-wide DRServiceManager. Every screen, and the Siri service, share this
    /// instance. Constructing a second one is expensive: each init() loads the disk cache
    /// and then fetches the whole catalogue, and a successful fetch kicks off an unbounded
    /// preload of every image in the schedule.
    @StateObject private var serviceManager = DRServiceManager()
    @StateObject private var deepLinkHandler = DeepLinkHandler()

    #if os(iOS) || os(macOS)
    @StateObject private var siriShortcutsService = SiriShortcutsService.shared
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serviceManager)
                .environmentObject(deepLinkHandler)
                #if os(iOS) || os(macOS)
                .environmentObject(siriShortcutsService)
                #endif
                .onOpenURL { url in
                    deepLinkHandler.handleDeepLink(url)
                }
                .task {
                    // Hand the Siri service the shared manager rather than letting it
                    // build one of its own.
                    #if os(iOS) || os(macOS)
                    siriShortcutsService.configure(with: serviceManager)
                    #endif
                }
        }
    }
}
