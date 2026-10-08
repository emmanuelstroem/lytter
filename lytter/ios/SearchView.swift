//
//  SearchView.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import SwiftUI

#if os(iOS) || os(visionOS)
// MARK: - Search View
/// The Search tab, laid out the way Music's is.
///
/// Before anything is typed: the stations you last chose from a search, then every station,
/// once each — P4 and P5 as stations, not ten districts apiece. Once something is typed: a
/// plain list of results, one row each, with a small picture, the name, and what it is —
/// which can be a single district, when that is what the words named (`StationSearch`).
///
/// The tab is declared with `role: .search`, so `.searchable` gets the system's
/// presentation: the field in the tab bar, and the keyboard up as the tab opens.
struct SearchView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    /// Observed directly, for the recent searches — see AGENTS.md.
    @ObservedObject var preferences: UserPreferencesService
    @State private var query = ""

    private var isSearching: Bool {
        !StationSearch.terms(query).isEmpty
    }

    private var results: [SearchHit] {
        StationSearch.results(for: query, in: serviceManager.availableChannels) { channel in
            serviceManager.getCurrentProgram(for: channel)?.searchableText ?? []
        }
    }

    var body: some View {
        NavigationStack {
            CatalogueStateView(serviceManager: serviceManager) {
                if isSearching {
                    resultsList
                } else {
                    SearchBrowseView(serviceManager: serviceManager, preferences: preferences,
                                     onPlay: { play($0, fromSearch: false) })
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "Stations, regions and programmes")
        }
        .onAppear {
            if serviceManager.availableChannels.isEmpty {
                serviceManager.loadChannels()
            }
        }
    }

    @ViewBuilder
    private var resultsList: some View {
        let results = results
        if results.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List {
                ConnectionBanner(serviceManager: serviceManager)
                    .listRowSeparator(.hidden)

                ForEach(results) { hit in
                    StationSearchRow(group: hit.group, match: hit.match,
                                     serviceManager: serviceManager,
                                     onPlay: { play($0, fromSearch: true) })
                }
            }
            .listStyle(.plain)
            #if os(iOS)
            // visionOS's keyboard floats apart from the window and has no such option.
            .scrollDismissesKeyboard(.immediately)
            #endif
            .contentMargins(.bottom, 100, for: .scrollContent) // Space for the mini player
        }
    }

    /// Plays a channel; from a search, it is remembered for the next visit.
    private func play(_ channel: DRChannel, fromSearch: Bool) {
        if fromSearch { preferences.recordSearch(of: channel.id) }
        serviceManager.playChannel(channel)
        selectionState.selectChannel(channel, showSheet: false)
    }
}

// MARK: - Browse

/// What Search shows before anything is typed.
private struct SearchBrowseView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var preferences: UserPreferencesService
    let onPlay: (DRChannel) -> Void

    private var recentSearches: [DRChannel] {
        preferences.recentSearches.resolve(in: serviceManager.availableChannels)
    }

    private var stations: [GroupedChannel] {
        GroupedChannel.grouped(from: serviceManager.availableChannels)
    }

    /// A scroll view of sections rather than a `List`, for Music's large section headings;
    /// a plain list's headers are small and pinned.
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ConnectionBanner(serviceManager: serviceManager)

                if !recentSearches.isEmpty {
                    section("Recently Searched",
                            groups: recentSearches.map { GroupedChannel(channels: [$0]) }) {
                        Button("Clear") { preferences.clearRecentSearches() }
                    }
                }

                section("All Stations", groups: stations) { EmptyView() }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100) // Space for the mini player
        }
        #if os(iOS)
        .scrollDismissesKeyboard(.immediately)
        #endif
    }

    private func section(_ title: LocalizedStringKey, groups: [GroupedChannel],
                         @ViewBuilder accessory: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.primary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                accessory()
            }

            ForEach(groups) { group in
                StationSearchRow(group: group, serviceManager: serviceManager, onPlay: onPlay)
                    .padding(.vertical, 6)
                // Inset to the text, as a list's separators are.
                Divider().padding(.leading, 60)
            }
        }
    }
}

// MARK: - Row

/// A station or a channel as a list row: picture, name, and what it is.
///
/// The row Music uses for a result. A station with districts opens the district picker,
/// and says so with a chevron; anything else plays.
struct StationSearchRow: View {
    let group: GroupedChannel
    /// Why it is listed. Found by what is on air, the row says what that is, even for a
    /// station that opens the picker.
    var match: SearchMatch = .station
    @ObservedObject var serviceManager: DRServiceManager
    let onPlay: (DRChannel) -> Void

    @State private var showingDistrictSheet = false

    private var channel: DRChannel { group.representative ?? group.channels[0] }

    private var opensPicker: Bool { group.hasMultipleDistricts }

    /// "Station · 10 districts" for a station that opens the picker; what is on now for one
    /// that plays, or for anything found by what is on.
    private var subtitle: String {
        if opensPicker && match != .programme {
            return String(localized: "Station · \(group.channels.count) districts")
        }
        return serviceManager.getCurrentProgram(for: channel)?.programmeName
            ?? String(localized: "Live")
    }

    var body: some View {
        Button {
            if opensPicker {
                showingDistrictSheet = true
            } else {
                onPlay(channel)
            }
        } label: {
            HStack(spacing: 12) {
                CachedAsyncImage(url: serviceManager.artworkURL(for: channel),
                                 maxPixelSize: ImageCacheService.thumbnailMaxPixelSize) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    StationArtworkPlaceholder(channel: channel)
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: group.displayTitle)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if !opensPicker && serviceManager.isAudible(channel) {
                    PlayingMark()
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                } else if opensPicker {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        // Without this the row's text takes the button tint and turns blue.
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(group.displayTitle), \(subtitle)"))
        .accessibilityHint(opensPicker ? "Choose a district" : "Plays this channel")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("search.row")
        .contextMenu {
            if !opensPicker {
                let isFavourite = serviceManager.userPreferences.isFavourite(channel.id)
                Button {
                    serviceManager.userPreferences.toggleFavourite(channel.id)
                } label: {
                    Label(isFavourite ? "Remove from Favourites" : "Add to Favourites",
                          systemImage: isFavourite ? "star.slash" : "star")
                }
            }
        }
        .sheet(isPresented: $showingDistrictSheet) {
            DistrictSelectionSheet(groupedChannel: group, serviceManager: serviceManager,
                                   onChannelSelect: onPlay)
        }
    }
}
#endif
