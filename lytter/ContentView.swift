//
//  ContentView.swift
//  lytter
//
//  Created by Emmanuel on 07/08/2025.
//

import SwiftUI

struct ContentView: View {
    /// Owned by lytterApp and shared with the Siri service — see the note there.
    @EnvironmentObject var serviceManager: DRServiceManager
    @StateObject private var selectionState = SelectionState()
    @SceneStorage("selectedTab") private var selectedTabIndex = 0

    @EnvironmentObject var deepLinkHandler: DeepLinkHandler
    
    #if os(iOS) || os(macOS)
    @EnvironmentObject var siriShortcutsService: SiriShortcutsService
    #endif
    
    var body: some View {
        #if os(iOS)
        ZStack {
            // Main TabView with TabBarMinimizeBehavior
            if #available(iOS 26.0, *) {
                TabView(selection: $selectedTabIndex) {
                    Tab("Home", systemImage: "house", value: 0) {
                        HomeView(serviceManager: serviceManager, selectionState: selectionState, deepLinkHandler: deepLinkHandler)
                    }
                    Tab("Radio", systemImage: "antenna.radiowaves.left.and.right", value: 1) {
                        iOSRadioView(serviceManager: serviceManager, selectionState: selectionState, deepLinkHandler: deepLinkHandler)
                    }
                    Tab("Search", systemImage: "magnifyingglass", value: 2, role: .search) {
                        SearchView(serviceManager: serviceManager, selectionState: selectionState, deepLinkHandler: deepLinkHandler)
                    }
                    Tab("Shortcuts", systemImage: "mic.circle", value: 3) {
                        ShortcutsView()
                            #if os(iOS) || os(macOS)
                            .environmentObject(siriShortcutsService)
                            #endif
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
                    HomeView(serviceManager: serviceManager, selectionState: selectionState, deepLinkHandler: deepLinkHandler)
                        .tabItem {
                            Image(systemName: "house")
                            Text("Home")
                        }
                    
                    // Radio Tab
                    iOSRadioView(serviceManager: serviceManager, selectionState: selectionState, deepLinkHandler: deepLinkHandler)
                        .tabItem {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                            Text("Radio")
                        }
                    
                    // Search Tab
                    SearchView(serviceManager: serviceManager, selectionState: selectionState, deepLinkHandler: deepLinkHandler)
                        .tabItem {
                            Image(systemName: "magnifyingglass")
                            Text("Search")
                        }
                    
                    // Shortcuts Tab
                    #if os(iOS) || os(macOS)
                    ShortcutsView()
                        .environmentObject(siriShortcutsService)
                        .tabItem {
                            Image(systemName: "mic.circle")
                            Text("Shortcuts")
                        }
                    #endif
                }
                .accentColor(.purple)
                
                // MiniPlayer positioned above TabView
                MiniPlayer()
                    .environmentObject(serviceManager)
                    .environmentObject(selectionState)
                    .frame(alignment: .bottom)
            }
        }
        // Presented here, not from the mini player: see SelectionState.isShowingFullPlayer.
        .sheet(isPresented: $selectionState.isShowingFullPlayer) {
            FullPlayerSheet(serviceManager: serviceManager, selectionState: selectionState)
        }
        .onContinueUserActivity("PlayChannelActivity") { userActivity in
            #if os(iOS) || os(macOS)
            siriShortcutsService.handleUserActivity(userActivity)
            #endif
        }
        
    #elseif os(tvOS)
        tvOSHomeView(
            serviceManager: serviceManager,
            selectionState: selectionState,
            deepLinkHandler: deepLinkHandler
        )
        .environmentObject(serviceManager)
        .environmentObject(selectionState)
        .onOpenURL { url in
            deepLinkHandler.handleDeepLink(url)
        }

    #endif
    }
}


#Preview {
    ContentView()
        .environmentObject(DRServiceManager())
        .environmentObject(DeepLinkHandler())
        #if os(iOS) || os(macOS)
        .environmentObject(SiriShortcutsService.shared)
        #endif
}
