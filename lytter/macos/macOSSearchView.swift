//
//  macOSSearchView.swift
//  lytter
//

import SwiftUI

#if os(macOS)
/// Search, as Music lays it out on the Mac.
///
/// The field is the sidebar's (`macOSContentView`). Before anything is typed this is every
/// station once, P4 and P5 as single cards; once something is typed, a section for each kind
/// of result — the stations and districts the words named, then the channels found by what
/// is on air (`StationSearch`).
struct macOSSearchView: View {
    @ObservedObject var serviceManager: DRServiceManager
    let query: String
    let onSelect: (DRChannel) -> Void

    private var results: [SearchHit] {
        StationSearch.results(for: query, in: serviceManager.availableChannels) { channel in
            serviceManager.getCurrentProgram(for: channel)?.searchableText ?? []
        }
    }

    private var isSearching: Bool { !StationSearch.terms(query).isEmpty }

    var body: some View {
        CatalogueStateView(serviceManager: serviceManager) {
            ScrollView {
                ConnectionBanner(serviceManager: serviceManager)
                    .padding([.horizontal, .top], 24)

                let results = results
                if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .padding(.top, 80)
                } else if isSearching {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        section("Stations", results.filter { $0.match != .programme })
                        section("On Air Now", results.filter { $0.match == .programme })
                    }
                    .padding(.vertical, 12)
                } else {
                    grid(results.map(\.group))
                }
            }
        }
        .onAppear {
            if serviceManager.availableChannels.isEmpty { serviceManager.loadChannels() }
        }
    }

    @ViewBuilder
    private func section(_ title: LocalizedStringKey, _ hits: [SearchHit]) -> some View {
        if !hits.isEmpty {
            Text(title)
                .font(.title2.weight(.bold))
                .padding(.horizontal, 24)
                .accessibilityAddTraits(.isHeader)
            grid(hits.map(\.group))
        }
    }

    private func grid(_ groups: [GroupedChannel]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 20)], spacing: 24) {
            ForEach(groups) { group in
                macOSStationCard(group: group, serviceManager: serviceManager,
                                  onSelect: onSelect)
            }
        }
        .padding(24)
    }
}
#endif
