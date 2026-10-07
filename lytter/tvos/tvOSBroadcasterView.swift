//
//  tvOSBroadcasterView.swift
//  lytter
//
//  Created by Assistant on 08/08/2025.
//

import SwiftUI

#if os(tvOS)
/// One broadcaster's stations in a row, under its name — a sidebar entry under
/// Broadcasters (F54c). Was the Radio tab, which listed every station; with
/// `broadcasterID` nil it still does, for tvOS 17, whose tab bar cannot hold a section.
struct tvOSBroadcasterView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    /// The broadcaster to list; nil for every one shown.
    let broadcasterID: String?
    // Sheet removed; districts are presented via Menu wrapping the channel card
    
    @FocusState private var focusedMenuChannelId: String?

    /// The heading: the broadcaster's name, or "Radio" for all of them.
    private var title: Text {
        guard let broadcasterID else { return Text("Radio") }
        let name = serviceManager.visibleBroadcasters.first { $0.id == broadcasterID }?.name
        return Text(verbatim: name ?? broadcasterID)
    }

    /// This view's channels: one broadcaster's, or all of them.
    private var channels: [DRChannel] {
        guard let broadcasterID else { return serviceManager.availableChannels }
        return serviceManager.availableChannels.filter { Broadcaster.supplying($0).id == broadcasterID }
    }
    
    // One representative per base channel (deduped by name)
    private var primaryChannels: [DRChannel] {
        // Was a local copy of the grouping. `GroupedChannel` is shared now, so tvOS and iOS
        // agree on what a station is by construction rather than by two functions happening
        // to behave the same.
        let ordered = GroupedChannel.grouped(from: channels)
            .compactMap(\.representative)
            .sorted { $0.title < $1.title }

        // Favourites first, as themselves. A pinned district channel is not a station
        // representative, so it would otherwise not appear at all — and putting it in
        // front is the whole point: one click, no variant menu.
        let favourites = serviceManager.userPreferences.favourites.resolve(in: channels)
        let pinned = Set(favourites.map(\.id))
        return favourites + ordered.filter { !pinned.contains($0.id) }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                LinearGradient(colors: [.black, .black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                VStack {
                    VStack(alignment: .leading, spacing: 32) {
                        // Section header — Music-app style
                        title
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 60)

                        ConnectionBanner(serviceManager: serviceManager)
                            .padding(.horizontal, 60)

                        CatalogueStateView(serviceManager: serviceManager) {
                            // Horizontal shelf — like the Music Home tab
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(alignment: .top, spacing: 40) {
                                    ForEach(primaryChannels, id: \.id) { channel in
                                        // The same card as Home and Search. Radio used to
                                        // build its own, with its own variant overlay and
                                        // its own focus bookkeeping; a station should not
                                        // look or behave differently depending on which
                                        // screen it is listed on.
                                        let variants = channels
                                            .filter { $0.stationKey == channel.stationKey }

                                        tvOSStationCard(
                                            group: GroupedChannel(channels: variants),
                                            serviceManager: serviceManager,
                                            onSelect: { picked in
                                                serviceManager.playChannel(picked)
                                                selectionState.selectChannel(picked)
                                            }
                                        )
                                        .focused($focusedMenuChannelId, equals: channel.id)
                                    }
                                }
                                .padding(.horizontal, 60)
                                .padding(.top, 50)    // room for 1.1x scale overflow upward
                                .padding(.bottom, 30)
                                .focusSection()
                            }
                        }
                    }
                    .padding(.top, 50)
                    // While variants overlay is visible, block interaction and hide focus effects behind it
                    .edgesIgnoringSafeArea(.horizontal)
                    
                }

            }
        }
        .onAppear {
            if serviceManager.availableChannels.isEmpty { serviceManager.loadChannels() }
        }
        // District selection is handled inline via Menu; no sheet presentation
    }
    
    // Selection is handled inline in the list via Button/Menu
    private func handleChannelSelection(_ channel: DRChannel) { }
}

/// A wrapper view that applies a ButtonStyle to any Menu label
struct MenuLabelButtonStyle<Style: ButtonStyle, Label: View>: View {
    let style: Style
    let label: Label
    
    init(style: Style, @ViewBuilder label: () -> Label) {
        self.style = style
        self.label = label()
    }
    
    var body: some View {
        Button(action: {}) {
            label
        }
        .buttonStyle(style)
        .allowsHitTesting(false) // Let Menu handle taps
    }
}

#endif

