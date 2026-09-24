//
//  tvOSHomeView.swift
//  lytter
//

import SwiftUI

#if os(tvOS)
/// Where the app opens on Apple TV.
///
/// There is no tab bar. The Music app on tvOS does not spend a permanent strip of the
/// screen on navigation, and neither does this: Home fills the screen, and the one control
/// at the top says where you are and pops over the places you can go.
///
/// Home itself is the same sectioned layout as iOS — Favourites, Recently Played, then one
/// shelf per broadcaster — built from the shared `GroupedChannel`, so the two platforms
/// agree on what a station is rather than each deciding separately.
struct tvOSHomeView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    @ObservedObject var deepLinkHandler: DeepLinkHandler

    @State private var section: tvOSSection = .home

    var body: some View {
        Group {
            if section == .nowPlaying {
                // Full-bleed, with no switcher over it: the artwork is the screen. The
                // remote's Menu button is the way back, which is where a tvOS viewer
                // already reaches for it.
                tvOSNowPlayingView(serviceManager: serviceManager)
                    .onExitCommand { section = .home }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    sectionSwitcher
                        .padding(.horizontal, 60)
                        .padding(.top, 40)
                        .padding(.bottom, 8)

                    sectionContent
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .environmentObject(serviceManager)
        .environmentObject(selectionState)
        .onChange(of: deepLinkHandler.shouldNavigateToChannel) { _, shouldNavigate in
            if shouldNavigate, let targetChannel = deepLinkHandler.targetChannel {
                handleDeepLinkChannel(targetChannel)
            }
        }
    }

    /// The only piece of chrome: what you are looking at, and a way to the rest.
    private var sectionSwitcher: some View {
        tvOSVariantMenu(
            items: tvOSSection.allCases,
            label: {
                HStack(spacing: 14) {
                    Image(systemName: section.systemImage)
                        .font(.system(size: 28, weight: .semibold))
                    Text(section.title)
                        .font(.system(size: 34, weight: .bold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
            },
            itemTitle: \.title,
            onSelect: { section = $0 },
            panelTitle: String(localized: "Go to")
        )
        .fixedSize()
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .home:
            shelves
        case .radio:
            tvOSRadioView(serviceManager: serviceManager, selectionState: selectionState)
        case .search:
            tvOSSearchView(serviceManager: serviceManager, selectionState: selectionState)
        case .nowPlaying:
            // Handled above, full-screen.
            EmptyView()
        }
    }

    private var shelves: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 48) {
                tvOSChannelShelf(
                    title: String(localized: "Favourites"),
                    groups: singles(serviceManager.userPreferences.favourites
                        .resolve(in: serviceManager.availableChannels)),
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
            .padding(.vertical, 24)
        }
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

/// Where the app can go. Was a tab bar; now it is a list in a pop-over.
enum tvOSSection: String, CaseIterable, Identifiable, Hashable {
    case home
    case radio
    case nowPlaying
    case search

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return String(localized: "Home")
        case .radio: return String(localized: "Radio")
        case .nowPlaying: return String(localized: "Now Playing")
        case .search: return String(localized: "Search")
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .radio: return "antenna.radiowaves.left.and.right"
        case .nowPlaying: return "play.circle"
        case .search: return "magnifyingglass"
        }
    }
}
#endif
