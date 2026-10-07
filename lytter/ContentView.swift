//
//  ContentView.swift
//  lytter
//
//  Created by Emmanuel on 07/08/2025.
//

import SwiftUI
import os

struct ContentView: View {
    /// `DRServiceManager.shared`, handed down by lytterApp — see the note there.
    @EnvironmentObject var serviceManager: DRServiceManager
    @StateObject private var selectionState = SelectionState()
    /// Always Home at launch. This was `@SceneStorage`, which restored the last tab, so a
    /// listener who had last searched reopened the app on Search. Home is where what they
    /// were listening to, their favourites and recents are.
    @State private var selectedTabIndex = 0

    @EnvironmentObject var deepLinkHandler: DeepLinkHandler
    
    var body: some View {
        #if os(iOS)
        ZStack {
            // Main TabView with TabBarMinimizeBehavior
            if #available(iOS 26.0, *) {
                TabView(selection: $selectedTabIndex) {
                    Tab("Home", systemImage: "house", value: 0) {
                        HomeView(serviceManager: serviceManager, selectionState: selectionState, preferences: serviceManager.userPreferences)
                    }
                    // No Radio tab: Home's *All* chip is every station (F54c).
                    Tab("Search", systemImage: "magnifyingglass", value: 2, role: .search) {
                        SearchView(serviceManager: serviceManager, selectionState: selectionState,
                                   preferences: serviceManager.userPreferences)
                    }
                    // Siri & Shortcuts is inside Settings now, rather than a tab of its own.
                    Tab("Settings", systemImage: "gearshape", value: 3) {
                        iOSSettingsView(preferences: serviceManager.userPreferences,
                                        channels: serviceManager.availableChannels)
                    }
                }
                .tabBarMinimizeBehavior(.onScrollDown)
                .accentColor(.purple)
                .tabViewBottomAccessory {
                    MiniPlayer()
                        .environmentObject(serviceManager)
                        .environmentObject(selectionState)
                }
            }
            else {
                // Fallback on earlier versions
                TabView {
                    // Home Tab
                    HomeView(serviceManager: serviceManager, selectionState: selectionState, preferences: serviceManager.userPreferences)
                        .tabItem {
                            Image(systemName: "house")
                            Text("Home")
                        }
                    
                    // Search Tab
                    SearchView(serviceManager: serviceManager, selectionState: selectionState,
                               preferences: serviceManager.userPreferences)
                        .tabItem {
                            Image(systemName: "magnifyingglass")
                            Text("Search")
                        }
                    
                    // Settings Tab
                    iOSSettingsView(preferences: serviceManager.userPreferences,
                                    channels: serviceManager.availableChannels)
                        .tabItem {
                            Image(systemName: "gearshape")
                            Text("Settings")
                        }
                }
                .accentColor(.purple)
                
                // MiniPlayer positioned above TabView
                MiniPlayer()
                    .environmentObject(serviceManager)
                    .environmentObject(selectionState)
                    .frame(alignment: .bottom)
            }
        }
        // Screen Off (F43): watches this window for interaction while playing.
        .background(ScreenOffInstaller(serviceManager: serviceManager))
        // Deep links resolve here, not per-screen.
        //
        // The same .onChange used to be copy-pasted onto HomeView, SearchView and
        // the Radio tab. Only the selected tab's view is alive, so a link arriving while
        // the Shortcuts tab was showing was observed by nobody and silently dropped —
        // and if more than one had been alive, the channel would have been played once
        // per copy. ContentView outlives every tab.
        .onChange(of: deepLinkHandler.shouldNavigateToChannel) { _, shouldNavigate in
            if shouldNavigate { resolveDeepLink() }
        }
        .onChange(of: serviceManager.availableChannels.count) { _, count in
            // A link opened from cold arrives before the catalogue. This is the retry.
            if count > 0 { resolveDeepLink() }
        }
        // Presented here, not from the mini player: see SelectionState.isShowingFullPlayer.
        .sheet(isPresented: $selectionState.isShowingFullPlayer) {
            FullPlayerSheet(serviceManager: serviceManager, selectionState: selectionState)
        }

    #elseif os(tvOS)
        tvOSHomeView(
            serviceManager: serviceManager,
            selectionState: selectionState,
            deepLinkHandler: deepLinkHandler
        )
        .environmentObject(serviceManager)
        .environmentObject(selectionState)
        .background(ScreenOffInstaller(serviceManager: serviceManager))
        .onOpenURL { url in
            deepLinkHandler.handleDeepLink(url)
        }

    #elseif os(macOS)
        macOSContentView(
            serviceManager: serviceManager,
            selectionState: selectionState,
            deepLinkHandler: deepLinkHandler
        )
        .environmentObject(serviceManager)
        .environmentObject(selectionState)

    #endif
    }

    #if os(iOS)
    /// Acts on a pending deep link, if the catalogue can resolve it yet.
    private func resolveDeepLink() {
        guard let identifier = deepLinkHandler.pendingChannelId else { return }

        if let channel = serviceManager.channel(forDeepLinkIdentifier: identifier) {
            Log.deepLink.debug("resolved to \(channel.slug, privacy: .public)")
            serviceManager.playChannel(channel)
            selectionState.selectChannel(channel, showSheet: false)
            deepLinkHandler.clearTarget()
            return
        }

        // Unresolved. Keep it only while a retry is still plausible: previously the link
        // was cleared on the first failed attempt, which is the attempt that happens
        // before the catalogue has loaded — so a link opened from cold cleared itself and
        // the retry it was waiting for could never fire.
        guard deepLinkHandler.isPendingLinkWorthRetrying else {
            Log.deepLink.warning("giving up on a link that names no known channel")
            deepLinkHandler.clearTarget()
            return
        }

        if serviceManager.availableChannels.isEmpty && !serviceManager.isLoading {
            serviceManager.loadChannels()
        }
    }
    #endif
}


#Preview {
    ContentView()
        .environmentObject(DRServiceManager())
        .environmentObject(DeepLinkHandler())
}
