//
//  ContentView.swift
//  lytter
//
//  Created by Emmanuel on 07/08/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    @StateObject private var serviceManager = DRServiceManager()
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
        .overlay(alignment: .topTrailing) {
            // Debug overlay to show Top Shelf extension heartbeat via App Group
            VStack(alignment: .trailing, spacing: 4) {
                if let defaults = UserDefaults(suiteName: "group.com.eopio.lytter") {
                    let ts = defaults.double(forKey: "TopShelfLastRun")
                    let count = defaults.integer(forKey: "TopShelfItemCount")
                    if ts > 0 {
                        Text("TopShelf: \(Date(timeIntervalSince1970: ts).formatted())")
                            .font(.caption2)
                            .foregroundColor(.white)
                        Text("Items: \(count)")
                            .font(.caption2)
                            .foregroundColor(.white)
                    } else {
                        Text("TopShelf: no heartbeat")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(8)
        }
    #endif
    }
}


#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
