//
//  tvOSSearchView.swift
//  lytter
//

import SwiftUI

#if os(tvOS)
/// Search, using the system's own presentation.
///
/// `.searchable` rather than a text field of our own: on tvOS that is the full-screen search
/// experience a viewer already knows, with the system keyboard and dictation, and none of it
/// is ours to maintain.
struct tvOSSearchView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState

    @State private var query = ""

    /// One entry per station, not one per district.
    ///
    /// P4 is ten channels and one station. Listing all ten filled the grid with the same
    /// artwork under the same name, ten times over, and buried every other station below it.
    ///
    /// The grouping does not cost reach: `matches` looks *inside* the group — at each
    /// variant's display name and slug as well as the station's — so "København" still finds
    /// P4 and P5, and "Bornholm" still finds them. It also matches what is on air, so
    /// "orientering" finds P1 while that programme is running, which is closer to how
    /// someone actually looks for live radio.
    private var results: [GroupedChannel] {
        GroupedChannel.grouped(from: serviceManager.availableChannels)
            .filter { group in
                group.matches(query, nowPlaying: { channel in
                    serviceManager.getCurrentProgram(for: channel)?.programmeName
                })
            }
    }

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 300), spacing: 40),
        count: 4
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .padding(.top, 120)
                } else {
                    LazyVGrid(columns: columns, spacing: 48) {
                        ForEach(results) { group in
                            tvOSShelfCard(
                                group: group,
                                serviceManager: serviceManager,
                                onSelect: play
                            )
                        }
                    }
                    // Focus lifts a card; without room the grid clips it.
                    .padding(.horizontal, 60)
                    .padding(.vertical, 40)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .searchable(text: $query, prompt: Text("Channels, districts, programmes"))
        }
        .onAppear {
            if serviceManager.availableChannels.isEmpty { serviceManager.loadChannels() }
        }
    }

    private func play(_ channel: DRChannel) {
        serviceManager.playChannel(channel)
        selectionState.selectChannel(channel)
    }
}
#endif
