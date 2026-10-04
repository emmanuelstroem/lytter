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
    @FocusState private var focusedCard: String?
    @State private var placedLaunchFocus = false

    /// True while the app is launching, when a plain cover hides the screen.
    ///
    /// tvOS shows a `.sidebarAdaptable` sidebar expanded at launch and collapses it only
    /// once focus is in the content. There is no API to start it collapsed: `.defaultFocus`,
    /// `.prefersDefaultFocus` and disabling every tab all left it open. Moving focus to the
    /// first card closes it within a second, but that read as a glitch — the sidebar
    /// peeking open and shutting again. So the cover stays until a card has focus and the
    /// sidebar has had time to fold away, then fades. If no card turns up within
    /// `launchHoldLimit` — a cold start on a slow connection — the cover lifts anyway and
    /// the sidebar, the one thing that can take focus, is there to use.
    @State private var holdingSidebar = true
    private static let launchHoldLimit: Duration = .seconds(5)
    /// Long enough for the sidebar's collapse animation to finish under the cover.
    private static let sidebarCollapseTime: Duration = .milliseconds(400)

    // Menu returns Home from Now Playing, and only from there. Every other section is a
    // grid or a list, so focus can always walk left into the sidebar. Now Playing fades its
    // controls out after a few seconds and fills the screen with artwork, and once they are
    // gone there is nothing to walk left *from* — the screen became a dead end with no way
    // back. Lost when this moved from a hand-rolled switcher to a TabView.

    var body: some View {
        Group {
            if #available(tvOS 18.0, *) {
                TabView(selection: $section) {
                    // First, at the top of the sidebar, as in the TV and Music apps (F36).
                    // role: .search so the sidebar gives it the system's search treatment
                    // rather than listing it as one destination among five.
                    Tab("Search", systemImage: "magnifyingglass", value: tvOSSection.search,
                        role: .search) {
                        tvOSSearchView(serviceManager: serviceManager,
                                       selectionState: selectionState)
                    }
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
                    // Last, at the bottom of the sidebar, as in the TV app (F37).
                    Tab("Settings", systemImage: "gearshape", value: tvOSSection.settings) {
                        tvOSSettingsView(preferences: serviceManager.userPreferences)
                    }
                }
                // No `.tabViewSidebarHeader` — the app name above the list would suit it,
                // but that modifier is tvOS 27 and this ships to 17.6.
                .tabViewStyle(.sidebarAdaptable)
                .task(launchHoldTimeout)
            } else {
                legacyTabs
            }
        }
        .overlay {
            if holdingSidebar {
                Color.black.ignoresSafeArea().allowsHitTesting(false)
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
            tvOSSearchView(serviceManager: serviceManager, selectionState: selectionState)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(tvOSSection.search)

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

            tvOSSettingsView(preferences: serviceManager.userPreferences)
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(tvOSSection.settings)
        }
        .tint(.white)
    }

    /// The shelves in order, as (title, groups, style). The view and the launch focus read
    /// the same list, so "the first card" is always the first card on screen.
    private var shelfContents: [(title: String, groups: [GroupedChannel], style: StationCardStyle)] {
        [(String(localized: "Favourites"),
          singles(serviceManager.userPreferences.favourites.resolve(in: serviceManager.availableChannels)),
          .featured),
         (String(localized: "Recently Played"),
          singles(serviceManager.userPreferences.recentlyPlayed.resolve(in: serviceManager.availableChannels)),
          .standard)]
        + serviceManager.broadcasterSections.map {
            ($0.broadcaster.name, GroupedChannel.grouped(from: $0.channels), .standard)
        }
    }

    private var shelves: some View {
        CatalogueStateView(serviceManager: serviceManager) {
            shelfList
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear(perform: placeLaunchFocus)
        .onChange(of: serviceManager.availableChannels.count) { _, _ in placeLaunchFocus() }
    }

    private var shelfList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 48) {
                // Above the shelves, inset to line up with their headings. A connection
                // problem with nothing to list is `CatalogueStateView`'s, full screen.
                ConnectionBanner(serviceManager: serviceManager)
                    .padding(.horizontal, 60)

                ForEach(shelfContents, id: \.title) { shelf in
                    tvOSChannelShelf(
                        title: shelf.title,
                        groups: shelf.groups,
                        style: shelf.style,
                        serviceManager: serviceManager,
                        onSelect: play,
                        focus: $focusedCard
                    )
                }
            }
            .padding(.vertical, 32)
        }
    }

    /// Puts focus on the first card, once, as soon as there is one. Left to the system, focus
    /// went to the sidebar's selected entry, which opens the sidebar over the content: every
    /// launch began on the list of sections until the system moved focus into the shelves
    /// some seconds later. The TV and Music apps open on their content, sidebar closed.
    /// The focus tag of the first card on screen, if there is one yet.
    private var firstCardKey: String? {
        guard let shelf = shelfContents.first(where: { !$0.groups.isEmpty }),
              let group = shelf.groups.first else { return nil }
        return tvOSChannelShelf.focusKey(title: shelf.title, group: group)
    }

    private func placeLaunchFocus() {
        guard holdingSidebar, !placedLaunchFocus, let key = firstCardKey else { return }
        placedLaunchFocus = true
        // Asking once was not enough. A card that cannot take focus yet — not laid out, or
        // the device still busy launching — drops the request silently. So keep asking, a
        // tenth of a second apart, until focus is on a card or the hold ends. `focusedCard`
        // follows real focus, so it is non-nil once a card has it.
        Task { @MainActor in
            while holdingSidebar {
                focusedCard = key
                try? await Task.sleep(for: .milliseconds(100))
                if focusedCard != nil {
                    try? await Task.sleep(for: Self.sidebarCollapseTime)
                    endLaunchHold()
                }
            }
        }
    }

    /// Ends the hold if no card has taken focus in time. From then on focus is left alone:
    /// content that turns up later must not pull focus out of a sidebar the viewer is using.
    @Sendable private func launchHoldTimeout() async {
        try? await Task.sleep(for: Self.launchHoldLimit)
        endLaunchHold()
    }

    private func endLaunchHold() {
        guard holdingSidebar else { return }
        withAnimation(.easeOut(duration: 0.25)) { holdingSidebar = false }
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
    case search
    case home
    case radio
    case nowPlaying
    case settings

    var id: String { rawValue }
}
#endif
