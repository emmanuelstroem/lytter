//
//  macOSContentView.swift
//  lytter
//

import SwiftUI

#if os(macOS)
/// Where the app opens on the Mac: a sidebar and a detail pane either side of a
/// `NavigationSplitView`, a docked player bar along the bottom — the shape of Music.app,
/// not a port of the phone's tab bar. A tab bar is a compromise for a screen too small to
/// show navigation and content at once; a Mac window has room for both, permanently, the
/// way Finder and Mail do it too.
struct macOSContentView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    @ObservedObject var deepLinkHandler: DeepLinkHandler

    @State private var section: macOSSection? = .home
    /// Held here, not by Search: the field is at the top of the sidebar, as in Music, and
    /// typing into it from anywhere opens Search.
    @State private var query = ""

    var body: some View {
        NavigationSplitView {
            List(selection: $section) {
                ForEach(macOSSection.destinations, id: \.self) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(item)
                }
                // One row per broadcaster shown, where Radio was (F54c) — the
                // counterpart of the chips on iPhone.
                Section("Broadcasters") {
                    ForEach(serviceManager.visibleBroadcasters) { broadcaster in
                        Label(broadcaster.name, systemImage: "antenna.radiowaves.left.and.right")
                            .tag(macOSSection.broadcaster(broadcaster.id))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            Group {
                switch section ?? .home {
                case .home:
                    macOSHomeView(serviceManager: serviceManager, onSelect: play)
                case .broadcaster(let id):
                    macOSBroadcasterView(serviceManager: serviceManager, broadcasterID: id,
                                         onSelect: play)
                case .search:
                    macOSSearchView(serviceManager: serviceManager, query: query, onSelect: play)
                }
            }
            .navigationTitle(title(of: section ?? .home))
        }
        .searchable(text: $query, placement: .sidebar,
                    prompt: Text("Stations, regions and programmes"))
        .onChange(of: query) { _, query in
            if !query.isEmpty { section = .search }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            macOSPlayerBar(serviceManager: serviceManager, selectionState: selectionState)
        }
        .sheet(isPresented: $selectionState.isShowingFullPlayer) {
            FullPlayerSheet(serviceManager: serviceManager, selectionState: selectionState)
        }
        .onChange(of: deepLinkHandler.shouldNavigateToChannel) { _, shouldNavigate in
            if shouldNavigate { resolveDeepLink() }
        }
        .onChange(of: serviceManager.availableChannels.count) { _, count in
            if count > 0 { resolveDeepLink() }
        }
        // A broadcaster hidden in Settings takes its row with it, and its page.
        .onChange(of: serviceManager.visibleBroadcasters) { _, visible in
            if case .broadcaster(let id) = section, !visible.contains(where: { $0.id == id }) {
                section = .home
            }
        }
    }

    private func title(of section: macOSSection) -> String {
        guard case .broadcaster(let id) = section else { return section.title }
        return serviceManager.visibleBroadcasters.first { $0.id == id }?.name ?? id
    }

    private func play(_ channel: DRChannel) {
        serviceManager.playChannel(channel)
        selectionState.selectChannel(channel, showSheet: false)
    }

    /// Shared with iOS in spirit, not in code: `ContentView.resolveDeepLink` is
    /// `#if os(iOS)`, tied to the tab bar's selection, which the sidebar has no
    /// equivalent of. Same resolution, same retry-until-the-catalogue-loads rule.
    private func resolveDeepLink() {
        guard let identifier = deepLinkHandler.pendingChannelId else { return }

        if let channel = serviceManager.channel(forDeepLinkIdentifier: identifier) {
            play(channel)
            deepLinkHandler.clearTarget()
            return
        }

        guard deepLinkHandler.isPendingLinkWorthRetrying else {
            deepLinkHandler.clearTarget()
            return
        }

        if serviceManager.availableChannels.isEmpty && !serviceManager.isLoading {
            serviceManager.loadChannels()
        }
    }
}

/// The sidebar's items: Home and Search, then a section of broadcasters — the places a
/// listener finds on iOS and tvOS too.
enum macOSSection: Hashable {
    case home, search
    /// One broadcaster's stations, under the sidebar's Broadcasters section.
    case broadcaster(String)

    /// The rows above the broadcasters, in order.
    static let destinations: [macOSSection] = [.home, .search]

    /// A destination's name. A broadcaster's is its own, which the section does not know.
    var title: String {
        switch self {
        case .home: String(localized: "Home")
        case .search: String(localized: "Search")
        case .broadcaster(let id): id
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .search: "magnifyingglass"
        case .broadcaster: "antenna.radiowaves.left.and.right"
        }
    }
}
#endif
