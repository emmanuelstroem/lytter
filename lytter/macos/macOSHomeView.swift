//
//  macOSHomeView.swift
//  lytter
//

import SwiftUI

#if os(macOS)
/// Favourites, favourite shows, Recently Played, one shelf per broadcaster — the same
/// sections as iOS and tvOS, built from the same `GroupedChannel`, so a Mac agrees with the
/// phone about what a station is rather than deciding again from scratch.
struct macOSHomeView: View {
    @ObservedObject var serviceManager: DRServiceManager
    let onSelect: (DRChannel) -> Void

    var body: some View {
        // Silence used to be the only state this screen had: an empty catalogue and a
        // catalogue still loading looked identical, because neither drew anything at all.
        // Loading, empty and failed are now `CatalogueStateView`'s, shared by every screen.
        CatalogueStateView(serviceManager: serviceManager) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 32) {
                    ConnectionBanner(serviceManager: serviceManager)

                    shelf(title: String(localized: "Favourites"),
                          groups: singles(serviceManager.userPreferences.favourites
                              .resolve(in: serviceManager.availableChannels)),
                          style: .featured)

                    macOSShowShelf(serviceManager: serviceManager,
                                   preferences: serviceManager.userPreferences,
                                   showSchedule: serviceManager.showSchedule)

                    shelf(title: String(localized: "Recently Played"),
                          groups: singles(serviceManager.userPreferences.recentlyPlayed
                              .resolve(in: serviceManager.availableChannels)))

                    ForEach(serviceManager.broadcasterSections) { section in
                        shelf(title: section.broadcaster.name,
                              groups: GroupedChannel.grouped(from: section.channels))
                    }
                }
                .padding(24)
            }
        }
        .onAppear {
            if serviceManager.availableChannels.isEmpty { serviceManager.loadChannels() }
        }
    }

    @ViewBuilder
    private func shelf(title: String, groups: [GroupedChannel],
                        style: StationCardStyle = .standard) -> some View {
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title2.weight(.bold))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 20) {
                        ForEach(groups) { group in
                            macOSStationCard(group: group, style: style,
                                              serviceManager: serviceManager,
                                              onSelect: onSelect)
                        }
                    }
                    // Room for the hover shadow and ring; without it the scroll view
                    // clips both at the row's edges.
                    .padding(.horizontal, 2)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    /// Wraps plain channels as single-channel groups, so the shelf takes one type.
    private func singles(_ channels: [DRChannel]) -> [GroupedChannel] {
        channels.map { GroupedChannel(channels: [$0]) }
    }
}
#endif
