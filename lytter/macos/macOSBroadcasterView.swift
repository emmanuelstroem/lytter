//
//  macOSBroadcasterView.swift
//  lytter
//

import SwiftUI

#if os(macOS)
/// One broadcaster's stations, as a grid — the library view, not the curated one Home is.
/// A row under the sidebar's Broadcasters section (F54c); it was Radio, every station.
struct macOSBroadcasterView: View {
    @ObservedObject var serviceManager: DRServiceManager
    let broadcasterID: String
    let onSelect: (DRChannel) -> Void

    private var groups: [GroupedChannel] {
        GroupedChannel.grouped(from: serviceManager.availableChannels
            .filter { Broadcaster.supplying($0).id == broadcasterID })
    }

    var body: some View {
        CatalogueStateView(serviceManager: serviceManager) {
            ScrollView {
                ConnectionBanner(serviceManager: serviceManager)
                    .padding([.horizontal, .top], 24)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 20)], spacing: 24) {
                    ForEach(groups) { group in
                        macOSStationCard(group: group, serviceManager: serviceManager,
                                          onSelect: onSelect)
                    }
                }
                .padding(24)
            }
        }
        .onAppear {
            if serviceManager.availableChannels.isEmpty { serviceManager.loadChannels() }
        }
    }
}
#endif
