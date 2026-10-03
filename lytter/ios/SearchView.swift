//
//  SearchView.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import SwiftUI

#if os(iOS)
// MARK: - Search View
/// The Search tab, laid out the way Music's is.
///
/// Before anything is typed: the stations you last chose from a search, then categories
/// to browse. Once something is typed: a plain list of results, one row each, with a small
/// picture, the name, and what kind of thing it is — not the grid of cards it used to be,
/// which was the Radio tab again with a search field on top.
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
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var results: [GroupedChannel] {
        GroupedChannel.grouped(from: serviceManager.availableChannels)
            .compactMap { group in
                group.searchResult(for: query) { channel in
                    serviceManager.getCurrentProgram(for: channel)?.cleanTitle()
                }
            }
    }

    var body: some View {
        NavigationStack {
            CatalogueStateView(serviceManager: serviceManager) {
                if isSearching {
                    resultsList
                } else {
                    SearchBrowseView(serviceManager: serviceManager, preferences: preferences,
                                     onPlay: play)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: SearchCategory.self) { category in
                SearchCategoryList(category: category, serviceManager: serviceManager,
                                   preferences: preferences, onPlay: play)
            }
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
        if results.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List {
                ConnectionBanner(serviceManager: serviceManager)
                    .listRowSeparator(.hidden)

                ForEach(results) { group in
                    StationSearchRow(group: group, serviceManager: serviceManager,
                                     onPlay: { play($0, fromSearch: true) })
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.immediately)
            .contentMargins(.bottom, 100, for: .scrollContent) // Space for the mini player
        }
    }

    /// Plays a channel; from a search, it is remembered for the next visit.
    private func play(_ channel: DRChannel, fromSearch: Bool) {
        if fromSearch { preferences.recordSearch(of: channel.id) }
        serviceManager.playChannel(channel)
        selectionState.selectChannel(channel, showSheet: false)
    }

    private func play(_ channel: DRChannel) {
        play(channel, fromSearch: false)
    }
}

// MARK: - Browse

/// A way into the catalogue other than typing, as Music's Browse Categories are.
enum SearchCategory: String, Hashable, CaseIterable, Identifiable {
    case favourites
    case recentlyPlayed
    case national
    case regional

    var id: String { rawValue }

    var title: String {
        switch self {
        case .favourites: String(localized: "Favourites")
        case .recentlyPlayed: String(localized: "Recently Played")
        case .national: String(localized: "National Stations")
        case .regional: String(localized: "Regional Stations")
        }
    }

    var systemImage: String {
        switch self {
        case .favourites: "star.fill"
        case .recentlyPlayed: "clock.fill"
        case .national: "antenna.radiowaves.left.and.right"
        case .regional: "map.fill"
        }
    }

    var colours: [Color] {
        switch self {
        case .favourites: [.yellow, .orange]
        case .recentlyPlayed: [.teal, .blue]
        case .national: [.purple, .indigo]
        case .regional: [.green, .teal]
        }
    }

    /// What the category lists, as rows. National stations are stations; regional ones
    /// are listed district by district, since choosing one is the point of going there.
    func groups(from channels: [DRChannel], preferences: UserPreferencesService) -> [GroupedChannel] {
        let stations = GroupedChannel.grouped(from: channels)
        switch self {
        case .favourites:
            return preferences.favourites.resolve(in: channels).map { GroupedChannel(channels: [$0]) }
        case .recentlyPlayed:
            return preferences.recentlyPlayed.resolve(in: channels).map { GroupedChannel(channels: [$0]) }
        case .national:
            return stations.filter { !$0.hasMultipleDistricts }
        case .regional:
            return stations.filter(\.hasMultipleDistricts)
                .flatMap { group in
                    group.channels(regionFirst: preferences.preferredDistrict)
                        .map { GroupedChannel(channels: [$0]) }
                }
        }
    }
}

/// What Search shows before anything is typed.
private struct SearchBrowseView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var preferences: UserPreferencesService
    let onPlay: (DRChannel) -> Void

    private var recentSearches: [DRChannel] {
        preferences.recentSearches.resolve(in: serviceManager.availableChannels)
    }

    /// Favourites and Recently Played only once they have something in them: a tile that
    /// opens onto an empty list is a dead end.
    private var categories: [SearchCategory] {
        SearchCategory.allCases.filter { category in
            switch category {
            case .favourites: !preferences.favourites.channelIDs.isEmpty
            case .recentlyPlayed: !preferences.recentlyPlayed.isEmpty
            case .national, .regional: true
            }
        }
    }

    /// A scroll view rather than a `List`: a list puts a disclosure chevron beside every
    /// tile that navigates, and Music's grid has none.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ConnectionBanner(serviceManager: serviceManager)

                if !recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Recently Searched")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Color.primary)
                                .accessibilityAddTraits(.isHeader)
                            Spacer()
                            Button("Clear") { preferences.clearRecentSearches() }
                        }

                        ForEach(recentSearches) { channel in
                            StationSearchRow(group: GroupedChannel(channels: [channel]),
                                             serviceManager: serviceManager,
                                             onPlay: onPlay)
                                .padding(.vertical, 6)
                            // Inset to the text, as a list's separators are.
                            Divider().padding(.leading, 60)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Browse Categories")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.primary)
                        .accessibilityAddTraits(.isHeader)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                        GridItem(.flexible(), spacing: 12)],
                              spacing: 12) {
                        ForEach(categories) { category in
                            NavigationLink(value: category) {
                                SearchCategoryTile(category: category)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100) // Space for the mini player
        }
        .scrollDismissesKeyboard(.immediately)
    }
}

/// One category: colour, symbol and name, as Music draws its genres.
private struct SearchCategoryTile: View {
    let category: SearchCategory

    var body: some View {
        LinearGradient(colors: category.colours, startPoint: .topLeading, endPoint: .bottomTrailing)
            .aspectRatio(16 / 10, contentMode: .fit)
            .overlay(alignment: .topTrailing) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .padding(12)
            }
            .overlay(alignment: .bottomLeading) {
                Text(category.title)
                    .font(.headline)
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.leading)
                    .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            // One element, named for the category; the link around it is the button.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: category.title))
    }
}

/// A category's stations, pushed from its tile.
private struct SearchCategoryList: View {
    let category: SearchCategory
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var preferences: UserPreferencesService
    let onPlay: (DRChannel) -> Void

    var body: some View {
        let groups = category.groups(from: serviceManager.availableChannels, preferences: preferences)
        List(groups) { group in
            StationSearchRow(group: group, serviceManager: serviceManager, onPlay: onPlay)
        }
        .listStyle(.plain)
        .contentMargins(.bottom, 100, for: .scrollContent)
        .overlay {
            if groups.isEmpty {
                ContentUnavailableView(category.title, systemImage: category.systemImage)
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Row

/// A station or a channel as a list row: picture, name, and what it is.
///
/// The row Music uses for a result. A station with districts opens the district picker,
/// and says so with a chevron; anything else plays.
struct StationSearchRow: View {
    let group: GroupedChannel
    @ObservedObject var serviceManager: DRServiceManager
    let onPlay: (DRChannel) -> Void

    @State private var showingDistrictSheet = false

    private var channel: DRChannel { group.representative ?? group.channels[0] }

    private var opensPicker: Bool { group.hasMultipleDistricts }

    /// "Station · 10 districts" for a station that opens the picker; what is on now for one
    /// that plays.
    private var subtitle: String {
        if opensPicker {
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
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
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
