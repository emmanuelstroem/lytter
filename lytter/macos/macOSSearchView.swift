//
//  macOSSearchView.swift
//  lytter
//

import SwiftUI

#if os(macOS)
struct macOSSearchView: View {
    @ObservedObject var serviceManager: DRServiceManager
    let onSelect: (DRChannel) -> Void

    @State private var query = ""

    private var results: [GroupedChannel] {
        GroupedChannel.grouped(from: serviceManager.availableChannels)
            .filter { group in
                group.matches(query) { channel in
                    serviceManager.getCurrentProgram(for: channel)?.programmeName
                }
            }
    }

    var body: some View {
        CatalogueStateView(serviceManager: serviceManager) {
            ScrollView {
                ConnectionBanner(serviceManager: serviceManager)
                    .padding([.horizontal, .top], 24)

                if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .padding(.top, 80)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 20)],
                              spacing: 24) {
                        ForEach(results) { group in
                            macOSStationCard(group: group, serviceManager: serviceManager,
                                              onSelect: onSelect)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .searchable(text: $query, placement: .toolbar,
                    prompt: Text("Channels and what's on now"))
        .onAppear {
            if serviceManager.availableChannels.isEmpty { serviceManager.loadChannels() }
        }
    }
}
#endif
