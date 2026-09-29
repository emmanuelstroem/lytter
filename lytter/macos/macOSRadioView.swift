//
//  macOSRadioView.swift
//  lytter
//

import SwiftUI

#if os(macOS)
/// Every station, as a grid — the library view, not the curated one Home is.
struct macOSRadioView: View {
    @ObservedObject var serviceManager: DRServiceManager
    let onSelect: (DRChannel) -> Void

    private var groups: [GroupedChannel] {
        GroupedChannel.grouped(from: serviceManager.availableChannels)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 20)], spacing: 24) {
                ForEach(groups) { group in
                    macOSStationCard(group: group, serviceManager: serviceManager,
                                      onSelect: onSelect)
                }
            }
            .padding(24)
        }
        .onAppear {
            if serviceManager.availableChannels.isEmpty { serviceManager.loadChannels() }
        }
    }
}
#endif
