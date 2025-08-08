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
            // Background gradient
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.95),
                    Color.black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Search")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Search functionality coming soon...")
                    .font(.title3)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.top, 60)
        }
        .onChange(of: deepLinkHandler.shouldNavigateToChannel) { shouldNavigate in
            if shouldNavigate, let targetChannel = deepLinkHandler.targetChannel {
                handleDeepLinkChannel(targetChannel)
            }
        }
    }
    
    private func handleDeepLinkChannel(_ targetChannel: DRChannel) {
        // Find the actual channel in available channels
        if let actualChannel = serviceManager.availableChannels.first(where: { $0.id == targetChannel.id }) {
            // Play the channel
            serviceManager.playChannel(actualChannel)
            selectionState.selectChannel(actualChannel, showSheet: false)
        }
        
        // Clear the deep link target
        deepLinkHandler.clearTarget()
    }
} 
#endif
