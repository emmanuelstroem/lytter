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

    /// Every station once before anything is typed — P4 is one card, not ten — and after,
    /// whatever answers: a station, a single district named by the words, or a channel by
    /// what is on air there (`StationSearch`).
    private var results: [SearchHit] {
        StationSearch.results(for: query, in: serviceManager.availableChannels) { channel in
            serviceManager.getCurrentProgram(for: channel)?.searchableText ?? []
        }
    }

    private var isSearching: Bool { !StationSearch.terms(query).isEmpty }

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 300), spacing: 40),
        count: 4
    )

    var body: some View {
        // The whole stack is pushed down, not just its content. The search field is placed
        // by the system at the top of the navigation stack, so insetting from the inside
        // moved the results and left the field where it was — under the sidebar rail, which
        // floats over the top-left corner and was covering the prompt.
        VStack(spacing: 0) {
            Color.clear.frame(height: 76)

            NavigationStack {
                ScrollView {
                    ConnectionBanner(serviceManager: serviceManager)
                        .padding(.horizontal, 60)
                        .padding(.top, 40)

                    CatalogueStateView(serviceManager: serviceManager) {
                        let results = results
                        if results.isEmpty {
                            ContentUnavailableView.search(text: query)
                                .padding(.top, 120)
                        } else if isSearching {
                            resultShelves(results)
                        } else {
                            allStations(results.map(\.group))
                        }
                    }
            }
            .background(Color.black.ignoresSafeArea())
            .searchable(text: $query, prompt: Text("Stations, regions and programmes"))
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            if serviceManager.availableChannels.isEmpty { serviceManager.loadChannels() }
        }
    }

    /// Before a search: every station, as a grid.
    private func allStations(_ groups: [GroupedChannel]) -> some View {
        LazyVGrid(columns: columns, spacing: 48) {
            ForEach(groups) { group in
                tvOSStationCard(group: group, serviceManager: serviceManager, onSelect: play)
            }
        }
        // Focus lifts a card; without room the grid clips it.
        .padding(.horizontal, 60)
        .padding(.vertical, 40)
    }

    /// Results as Music lists them on the television: a shelf for each kind, the stations
    /// and channels the words named first, then those found by what is on air.
    private func resultShelves(_ results: [SearchHit]) -> some View {
        LazyVStack(alignment: .leading, spacing: 24) {
            tvOSChannelShelf(title: String(localized: "Stations"),
                             groups: results.filter { $0.match != .programme }.map(\.group),
                             serviceManager: serviceManager, onSelect: play)
            tvOSChannelShelf(title: String(localized: "On Air Now"),
                             groups: results.filter { $0.match == .programme }.map(\.group),
                             serviceManager: serviceManager, onSelect: play)
        }
        .padding(.vertical, 20)
    }

    private func play(_ channel: DRChannel) {
        serviceManager.playChannel(channel)
        selectionState.selectChannel(channel)
    }
}
#endif
