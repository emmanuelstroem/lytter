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
///
/// The broadcaster's shelf on Home, on a page of its own: the same `tvOSChannelShelf`, set
/// out as Home sets out its list. It was built separately, and had drifted — a larger
/// heading, other spacing, and the screen's horizontal safe area ignored, which put the
/// heading and the first card 80 points nearer the edge of the screen than Home's.
/// `TVBroadcasterPageUITests` holds the two to the same places.
struct tvOSBroadcasterView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    /// The broadcaster to list; nil for every one shown.
    let broadcasterID: String?

    /// The heading: the broadcaster's name, or "Radio" for all of them.
    private var title: String {
        guard let broadcasterID else { return String(localized: "Radio") }
        return serviceManager.visibleBroadcasters.first { $0.id == broadcasterID }?.name
            ?? broadcasterID
    }

    /// This view's channels: one broadcaster's, or all of them.
    private var channels: [DRChannel] {
        guard let broadcasterID else { return serviceManager.availableChannels }
        return serviceManager.availableChannels.filter { Broadcaster.supplying($0).id == broadcasterID }
    }

    var body: some View {
        CatalogueStateView(serviceManager: serviceManager) {
            // Home's list, without the scrolling: one shelf has nothing to scroll to.
            VStack(alignment: .leading, spacing: 48) {
                ConnectionBanner(serviceManager: serviceManager)
                    .padding(.horizontal, 60)

                // One card per station, A to Z, as on the phone's broadcaster page (F54c),
                // and grouped as Home groups it, so a station looks and behaves the same
                // wherever it is listed.
                tvOSChannelShelf(
                    title: title,
                    groups: GroupedChannel.grouped(from: channels),
                    serviceManager: serviceManager,
                    onSelect: { picked in
                        serviceManager.playChannel(picked)
                        selectionState.selectChannel(picked)
                    }
                )
            }
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            if serviceManager.availableChannels.isEmpty { serviceManager.loadChannels() }
        }
    }
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
