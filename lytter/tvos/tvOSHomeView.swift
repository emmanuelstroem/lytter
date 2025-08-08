//
//  tvOSHomeView.swift
//  lytter
//
//  Created by Assistant on 08/08/2025.
//

import SwiftUI

#if os(tvOS)
struct tvOSHomeView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    @ObservedObject var deepLinkHandler: DeepLinkHandler

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            tvOSRadioView(serviceManager: serviceManager, selectionState: selectionState)
                .tabItem {
                    Label("Radio", systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(0)

            tvOSNowPlayingView(serviceManager: serviceManager)
                .tabItem {
                    Label("Now Playing", systemImage: "play.circle")
                }
                .tag(1)

            tvOSSearchView(serviceManager: serviceManager, selectionState: selectionState)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(2)
        }
        .tint(.white)
        .environmentObject(serviceManager)
        .environmentObject(selectionState)
        .onChange(of: deepLinkHandler.shouldNavigateToChannel) { shouldNavigate in
            if shouldNavigate, let targetChannel = deepLinkHandler.targetChannel {
                handleDeepLinkChannel(targetChannel)
            }
        }
    }

    private func handleDeepLinkChannel(_ targetChannel: DRChannel) {
        if let actualChannel = serviceManager.availableChannels.first(where: { $0.id == targetChannel.id }) {
            serviceManager.playChannel(actualChannel)
            selectionState.selectChannel(actualChannel)
            selectedTab = 1 // Switch to Now Playing
        }
        deepLinkHandler.clearTarget()
    }
}
#endif

