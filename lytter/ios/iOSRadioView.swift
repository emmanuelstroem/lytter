//
//  RadioView.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import SwiftUI

#if os(iOS)
struct iOSRadioView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    @State private var searchText = ""
    @State private var isLoading = false
    
    var filteredGroupedChannels: [GroupedChannel] {
        GroupedChannel.grouped(from: serviceManager.availableChannels)
            .filter { group in
                group.matches(searchText) { channel in
                    serviceManager.getCurrentProgram(for: channel)?.cleanTitle()
                }
            }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                
                VStack(spacing: 0) {
                    // Search bar
                    SearchBar(text: $searchText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    
                    // Channel list
                    if serviceManager.isLoading {
                        LoadingView()
                    } else if let error = serviceManager.error {
                        ErrorView(error: error) {
                            serviceManager.loadChannels()
                        }
                    } else if filteredGroupedChannels.isEmpty {
                        EmptyStateView()
                    } else {
                        ScrollView {
                            // The same card as Home, in a grid. Radio was a list of rows
                            // with a thumbnail — a second way of drawing a station, in the
                            // one place you go to look at all of them.
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 16)],
                                      spacing: 20) {
                                ForEach(filteredGroupedChannels) { groupedChannel in
                                    ChannelShelfCard(
                                        group: groupedChannel,
                                        serviceManager: serviceManager,
                                        onTap: { channel in
                                            serviceManager.playChannel(channel)
                                            selectionState.selectChannel(channel, showSheet: false)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 100) // Space for mini player
                        }
                    }
                }
            }
            .navigationTitle("Radio")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            // Load channels if not already loaded
            if serviceManager.availableChannels.isEmpty {
                serviceManager.loadChannels()
            }
        }
    }
}



#endif




