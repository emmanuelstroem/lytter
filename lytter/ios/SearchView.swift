//
//  SearchView.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import SwiftUI

#if os(iOS)
// MARK: - Search View
struct SearchView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    @ObservedObject var deepLinkHandler: DeepLinkHandler
    
    var body: some View {
        ZStack {
            AppBackground()
            
            VStack(spacing: 20) {
                Text("Search")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.primary)
                
                Text("Search functionality coming soon...")
                    .font(.title3)
                    .foregroundStyle(Color.secondary)
                
                Spacer()
            }
            .padding(.top, 60)
        }
        .onChange(of: deepLinkHandler.shouldNavigateToChannel) { _, shouldNavigate in
            if shouldNavigate, let targetChannel = deepLinkHandler.targetChannel {
                handleDeepLinkChannel(targetChannel)
            }
        }
    }
    
    private func handleDeepLinkChannel(_ targetChannel: DRChannel) {
        // Find the actual channel in available channels
        if let actualChannel = serviceManager.channel(forDeepLinkIdentifier: targetChannel.id) {
            // Play the channel
            serviceManager.playChannel(actualChannel)
            selectionState.selectChannel(actualChannel, showSheet: false)
        }
        
        // Clear the deep link target
        deepLinkHandler.clearTarget()
    }
} 
#endif
