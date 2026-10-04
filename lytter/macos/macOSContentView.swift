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
            List(macOSSection.allCases, selection: $section) { item in
                Label(item.title, systemImage: item.systemImage)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            Group {
                switch section ?? .home {
                case .home:
                    macOSHomeView(serviceManager: serviceManager, onSelect: play)
                case .radio:
                    macOSRadioView(serviceManager: serviceManager, onSelect: play)
                case .search:
                    macOSSearchView(serviceManager: serviceManager, query: query, onSelect: play)
                }
            }
            .navigationTitle((section ?? .home).title)
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
    }

    private func play(_ channel: DRChannel) {
        serviceManager.playChannel(channel)
        selectionState.selectChannel(channel, showSheet: false)
    }

    /// Shared with iOS in spirit, not in code: `ContentView.resolveDeepLink` is
    /// `#if os(iOS)`, tied to `@SceneStorage`'s tab index, which the sidebar has no
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

/// The sidebar's items. Three, matching iOS and tvOS — Home, Radio, Search — so a listener
/// finds the same three places on every screen they own.
enum macOSSection: String, CaseIterable, Identifiable, Hashable {
    case home, radio, search

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: String(localized: "Home")
        case .radio: String(localized: "Radio")
        case .search: String(localized: "Search")
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .radio: "antenna.radiowaves.left.and.right"
        case .search: "magnifyingglass"
        }
    }
}
#endif
