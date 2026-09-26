//
//  SearchView.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import SwiftUI

#if os(iOS)
// MARK: - Search View
/// The Search tab.
///
/// It shipped as a placeholder reading "Search functionality coming soon...". The tab is
/// declared with `role: .search`, so `.searchable` here gets the system's search
/// presentation rather than the hand-rolled `SearchBar` the Radio tab uses.
struct SearchView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    @State private var query = ""

    private var results: [GroupedChannel] {
        GroupedChannel.grouped(from: serviceManager.availableChannels)
            .filter { group in
                group.matches(query) { channel in
                    serviceManager.getCurrentProgram(for: channel)?.cleanTitle()
                }
            }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if serviceManager.isLoading && serviceManager.availableChannels.isEmpty {
                    LoadingView()
                } else if let error = serviceManager.error, serviceManager.availableChannels.isEmpty {
                    ErrorView(error: error) { serviceManager.loadChannels() }
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 16)],
                                  spacing: 20) {
                            ForEach(results) { groupedChannel in
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
                        .padding(.bottom, 100) // Space for the mini player
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "Channels and what's on now")
        }
        .onAppear {
            if serviceManager.availableChannels.isEmpty {
                serviceManager.loadChannels()
            }
        }
    }
}
#endif
