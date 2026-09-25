//
//  tvOSHomeView.swift
//  lytter
//

import SwiftUI

#if os(tvOS)
/// Where the app opens on Apple TV.
///
/// Navigation is the system's sidebar — the one the TV and Music apps use, which sits at the
/// left edge and slides out over dimmed content when focus reaches it.
/// `.tabViewStyle(.sidebarAdaptable)` is exactly that, and it arrived in tvOS 18; below that
/// a plain `TabView` still gives the top tab bar this screen had before.
///
/// Home itself is the same sectioned layout as iOS — Favourites, Recently Played, then one
/// shelf per broadcaster — built from the shared `GroupedChannel`, so the platforms agree on
/// what a station is rather than each deciding separately.
struct tvOSHomeView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    @ObservedObject var deepLinkHandler: DeepLinkHandler

    @State private var section: tvOSSection = .home

    // Menu returns Home from Now Playing, and only from there. Every other section is a
    // grid or a list, so focus can always walk left into the sidebar. Now Playing fades its
    // controls out after a few seconds and fills the screen with artwork, and once they are
    // gone there is nothing to walk left *from* — the screen became a dead end with no way
    // back. Lost when this moved from a hand-rolled switcher to a TabView.

    var body: some View {
        Group {
            if #available(tvOS 18.0, *) {
                TabView(selection: $section) {
                    Tab("Home", systemImage: "house", value: tvOSSection.home) {
                        shelves
                    }
                    Tab("Radio", systemImage: "antenna.radiowaves.left.and.right",
                        value: tvOSSection.radio) {
                        tvOSRadioView(serviceManager: serviceManager,
                                      selectionState: selectionState)
                    }
                    Tab("Now Playing", systemImage: "play.circle",
                        value: tvOSSection.nowPlaying) {
                        tvOSNowPlayingView(serviceManager: serviceManager)
                            .onExitCommand { section = .home }
                    }
                    // role: .search so the sidebar gives it the system's search treatment
                    // rather than listing it as one destination among four.
                    Tab("Search", systemImage: "magnifyingglass", value: tvOSSection.search,
                        role: .search) {
                        tvOSSearchView(serviceManager: serviceManager,
                                       selectionState: selectionState)
                    }
                }
                // No `.tabViewSidebarHeader` — the app name above the list would suit it,
                // but that modifier is tvOS 27 and this ships to 17.6.
                .tabViewStyle(.sidebarAdaptable)
            } else {
                legacyTabs
            }
        }
        .environmentObject(serviceManager)
        .environmentObject(selectionState)
        .onChange(of: deepLinkHandler.shouldNavigateToChannel) { _, shouldNavigate in
            if shouldNavigate, let targetChannel = deepLinkHandler.targetChannel {
                handleDeepLinkChannel(targetChannel)
            }
        }
    }

    /// tvOS 17 has no sidebar style, so it keeps the tab bar it always had.
    private var legacyTabs: some View {
        TabView(selection: $section) {
            shelves
                .tabItem { Label("Home", systemImage: "house") }
                .tag(tvOSSection.home)

            tvOSRadioView(serviceManager: serviceManager, selectionState: selectionState)
                .tabItem { Label("Radio", systemImage: "antenna.radiowaves.left.and.right") }
                .tag(tvOSSection.radio)

            tvOSNowPlayingView(serviceManager: serviceManager)
                .onExitCommand { section = .home }
                .tabItem { Label("Now Playing", systemImage: "play.circle") }
                .tag(tvOSSection.nowPlaying)

            tvOSSearchView(serviceManager: serviceManager, selectionState: selectionState)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(tvOSSection.search)
        }
        .tint(.white)
    }

    private var shelves: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 48) {
                tvOSChannelShelf(
                    title: String(localized: "Favourites"),
                    groups: singles(serviceManager.userPreferences.favourites
                        .resolve(in: serviceManager.availableChannels)),
                    size: .large,
                    serviceManager: serviceManager,
                    onSelect: play
                )

                tvOSChannelShelf(
                    title: String(localized: "Recently Played"),
                    groups: singles(serviceManager.userPreferences.recentlyPlayed
                        .resolve(in: serviceManager.availableChannels)),
                    serviceManager: serviceManager,
                    onSelect: play
                )

                ForEach(serviceManager.broadcasterSections) { broadcasterSection in
                    tvOSChannelShelf(
                        title: broadcasterSection.broadcaster.name,
                        groups: GroupedChannel.grouped(from: broadcasterSection.channels),
                        serviceManager: serviceManager,
                        onSelect: play
                    )
                }
            }
            .padding(.vertical, 32)
        }
        .background(Color.black.ignoresSafeArea())
    }

    /// Wraps plain channels as single-channel groups, so the shelf takes one type.
    private func singles(_ channels: [DRChannel]) -> [GroupedChannel] {
        channels.map { GroupedChannel(channels: [$0]) }
    }

    private func play(_ channel: DRChannel) {
        serviceManager.playChannel(channel)
        selectionState.selectChannel(channel)
        section = .nowPlaying
    }

    private func handleDeepLinkChannel(_ targetChannel: DRChannel) {
        if let actualChannel = serviceManager.channel(forDeepLinkIdentifier: targetChannel.id) {
            serviceManager.playChannel(actualChannel)
            selectionState.selectChannel(actualChannel)
            section = .nowPlaying
        }
        deepLinkHandler.clearTarget()
    }
}

/// The app's top-level destinations, and the sidebar's selection.
enum tvOSSection: String, CaseIterable, Identifiable, Hashable {
    case home
    case radio
    case nowPlaying
    case search

    var id: String { rawValue }
}
#endif
