//
//  HomeView.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import SwiftUI
import os

#if os(iOS) || os(visionOS)
/// Home, under a row of chips: *For you* · *All* · one per broadcaster (F54c).
///
/// *All* is what the Radio tab was, so there is no Radio tab: one place lists stations,
/// and the chips say which. Every broadcaster shown has a chip, DR's too while it is the
/// only one — see
/// `HomeScope.available`.
struct HomeView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    /// Observed directly: a nested ObservableObject does not republish through its owner,
    /// so pinning a channel would update the store and redraw nothing. That cost a debug
    /// cycle in #26.
    @ObservedObject var preferences: UserPreferencesService

    /// The chip last chosen, kept across launches. Empty until one has been tapped.
    @AppStorage("homeScope") private var storedScope = ""
    /// This session's scope, fixed when Home first appears. Without it, a first launch
    /// opening on *All* would jump to *For you* the moment the first station was played.
    @State private var chosenScope: HomeScope?

    private var availableScopes: [HomeScope] {
        HomeScope.available(visible: serviceManager.visibleBroadcasters)
    }

    private var hasOwnStations: Bool {
        !preferences.favourites.isEmpty || !preferences.recentlyPlayed.isEmpty
    }

    private var scope: HomeScope {
        let scope = chosenScope ?? HomeScope.initial(stored: storedScope, available: availableScopes,
                                                     hasOwnStations: hasOwnStations)
        return HomeScope.resolved(scope, in: availableScopes)
    }

    private func choose(_ scope: HomeScope) {
        chosenScope = scope
        storedScope = scope.storageValue
    }

    /// Lets go of a chip that is no longer offered — its broadcaster has been hidden — so
    /// that showing the broadcaster again leaves Home on *All*, where it fell back to,
    /// rather than jumping back to the chip.
    private func forgetUnavailableChoice() {
        if let stored = HomeScope(storageValue: storedScope), !availableScopes.contains(stored) {
            storedScope = HomeScope.all.storageValue
        }
        if let chosenScope, !availableScopes.contains(chosenScope) {
            self.chosenScope = .all
        }
    }

    /// Wraps plain channels as single-channel groups, so the shelf can take one type.
    /// A group of one has no districts, so tapping it plays rather than opening a picker.
    private func singles(_ channels: [DRChannel]) -> [GroupedChannel] {
        channels.map { GroupedChannel(channels: [$0]) }
    }

    private var favourites: [DRChannel] {
        preferences.favourites.resolve(in: serviceManager.availableChannels)
    }

    private var recentlyPlayed: [DRChannel] {
        preferences.recentlyPlayed.resolve(in: serviceManager.availableChannels)
    }

    private func play(_ channel: DRChannel) {
        serviceManager.playChannel(channel)
        selectionState.selectChannel(channel, showSheet: false)
    }

    var body: some View {
        // No navigation container: this screen has no title, no toolbar and no links,
        // so NavigationView was contributing an empty bar and nothing else. The header
        // it does show is drawn inside the ScrollView.
        ZStack {
            AppBackground()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        HomeHeader()
                            .id(Self.top)

                        HomeScopeChips(scopes: availableScopes, selected: scope,
                                       broadcasters: serviceManager.visibleBroadcasters,
                                       onSelect: choose)

                        ConnectionBanner(serviceManager: serviceManager)

                        CatalogueStateView(serviceManager: serviceManager) {
                            switch scope {
                            case .forYou: forYou
                            case .all: all
                            case .broadcaster(let id): broadcaster(id)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100) // Space for bottom tab bar
                }
                // A chip chosen from far down — *See all* under the last shelf — would
                // otherwise open its page scrolled to wherever that shelf was.
                .onChange(of: chosenScope) { _, _ in
                    withAnimation { proxy.scrollTo(Self.top, anchor: .top) }
                }
            }

            // A sibling of the background rather than an overlay on the scroll view: as an
            // overlay it inherits the scroll view's already-inset frame, so it drew an
            // 18-point band below the status bar instead of behind it.
            StatusBarScrim()
        }
        .onAppear {
            forgetUnavailableChoice()
            if chosenScope == nil { chosenScope = scope }
        }
        .onChange(of: availableScopes) { _, _ in forgetUnavailableChoice() }
    }

    private static let top = "home.top"

    // MARK: - Scopes

    /// Favourites, favourite shows, history. Each draws nothing when it has nothing, so
    /// with none of them there is a line saying what will come here instead of a blank.
    @ViewBuilder
    private var forYou: some View {
        ChannelShelf(
            title: String(localized: "Favourites"),
            groups: singles(favourites),
            style: .featured,
            serviceManager: serviceManager,
            onChannelTap: play
        )

        // Favourite shows (F33), under the channels: when each is next on.
        ShowShelf(serviceManager: serviceManager,
                  preferences: preferences,
                  showSchedule: serviceManager.showSchedule)

        ChannelShelf(
            title: String(localized: "Recently Played"),
            groups: singles(recentlyPlayed),
            serviceManager: serviceManager,
            onChannelTap: play
        )

        if favourites.isEmpty && recentlyPlayed.isEmpty && preferences.favouriteShows.isEmpty {
            Text("Your favourites and the stations you play appear here.")
                .font(.subheadline)
                .foregroundStyle(Color.secondaryOnPage)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        }
    }

    /// One shelf per broadcaster, each opening its own chip. With one broadcaster, its
    /// stations as the grid the Radio tab was: one shelf would hide most of them.
    @ViewBuilder
    private var all: some View {
        let sections = serviceManager.broadcasterSections
        if sections.count == 1, let only = sections.first {
            stationGrid(only)
        } else {
            ForEach(sections) { section in
                ChannelShelf(
                    title: section.broadcaster.name,
                    groups: GroupedChannel.grouped(from: section.channels),
                    serviceManager: serviceManager,
                    onChannelTap: play,
                    onSeeAll: { choose(.broadcaster(section.broadcaster.id)) }
                )
            }
        }
    }

    /// One broadcaster: every one of its stations, A to Z. Not its favourites first — they
    /// are on *For you*, and above the grid they listed P4 a second time, out of order.
    @ViewBuilder
    private func broadcaster(_ id: String) -> some View {
        if let section = serviceManager.broadcasterSections.first(where: { $0.broadcaster.id == id }) {
            stationGrid(section)
        }
    }

    /// Every station of `section`, under its broadcaster's name, in a grid. Districts
    /// still fold into one card per station.
    private func stationGrid(_ section: BroadcasterSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: section.broadcaster.name)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 16)

            ChannelGrid(groups: GroupedChannel.grouped(from: section.channels),
                        serviceManager: serviceManager,
                        onChannelTap: play)
                .padding(.horizontal, 16)
        }
    }
}

/// The chips under Home's header. Free-standing capsules, so no corner of theirs meets
/// another's (AGENTS.md, Concentricity); the selected one is the prominent one.
private struct HomeScopeChips: View {
    let scopes: [HomeScope]
    let selected: HomeScope
    let broadcasters: [Broadcaster]
    let onSelect: (HomeScope) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(scopes, id: \.self) { scope in
                    chip(scope)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func chip(_ scope: HomeScope) -> some View {
        let button = Button { onSelect(scope) } label: { title(scope) }
            .buttonBorderShape(.capsule)
            .accessibilityIdentifier("home.scope.\(scope.storageValue)")
            .accessibilityAddTraits(scope == selected ? .isSelected : [])

        if scope == selected {
            button.buttonStyle(.borderedProminent)
        } else {
            // Neutral rather than the accent: one purple chip says which is chosen.
            #if os(visionOS)
            // On glass the untinted bordered chip is already neutral. Tinted with the
            // primary colour, which is white there, it came out white on white; left to
            // inherit, it took the window's purple, and every chip looked chosen.
            button.buttonStyle(.bordered).tint(nil)
            #else
            button.buttonStyle(.bordered).tint(Color.primary)
            #endif
        }
    }

    private func title(_ scope: HomeScope) -> Text {
        switch scope {
        case .forYou: Text("For you")
        case .all: Text("All")
        case .broadcaster(let id):
            // Proper nouns, not localised.
            Text(verbatim: broadcasters.first { $0.id == id }?.name ?? id)
        }
    }
}

#endif

// MARK: - Home Header
struct HomeHeader: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lyt")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.primary)
                
                Text("Live Danish Radio")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryOnPage)
            }
            
            Spacer()
            
            // User profile picture
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
        }
        .padding(.top, 8)
    }
}

// MARK: - Glass Effect Container
//@available(iOS 26.0, *)
//struct GlassEffectContainer<Content: View>: View {
//    let content: Content
//    
//    init(@ViewBuilder content: () -> Content) {
//        self.content = content()
//    }
//    
//    var body: some View {
//        content
//            .background(.ultraThinMaterial)
//            .clipShape(RoundedRectangle(cornerRadius: 16))
//            .overlay(
//                RoundedRectangle(cornerRadius: 16)
//                    .stroke(.white.opacity(0.2), lineWidth: 1)
//            )
//    }
//}

#Preview {
    let manager = DRServiceManager()
    HomeView(
        serviceManager: manager,
        selectionState: SelectionState(),
        preferences: manager.userPreferences
    )
}
