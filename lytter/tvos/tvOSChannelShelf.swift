//
//  tvOSChannelShelf.swift
//  lytter
//

import SwiftUI

#if os(tvOS)
/// A horizontally scrolling row of channels under a heading.
///
/// The tvOS half of the sectioned home. It takes the same `GroupedChannel` as its iOS
/// counterpart and makes the same promises: one card whether the station has one variant or
/// ten, and nothing drawn at all when the row is empty, so a first launch shows the
/// catalogue rather than two empty headings.
struct tvOSChannelShelf: View {
    let title: String
    let groups: [GroupedChannel]
    @ObservedObject var serviceManager: DRServiceManager
    let onSelect: (DRChannel) -> Void

    var body: some View {
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 60)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 40) {
                        ForEach(groups) { group in
                            tvOSShelfCard(
                                group: group,
                                serviceManager: serviceManager,
                                onSelect: onSelect
                            )
                        }
                    }
                    .padding(.horizontal, 60)
                    // Focus lifts and shadows a card. Without room around the row the
                    // focused card is clipped by the scroll view it lives in.
                    .padding(.vertical, 30)
                }
            }
        }
    }
}

/// One card standing for a station.
///
/// Mirrors the iOS card's rule about districts, because the preference is shared: a station
/// plays the listener's region when it broadcasts one, and only asks when it does not know
/// which they want. Shared with search rather than private to this file, so a result behaves
/// exactly as the same station does on a shelf.
struct tvOSShelfCard: View {
    let group: GroupedChannel
    @ObservedObject var serviceManager: DRServiceManager
    let onSelect: (DRChannel) -> Void

    private var preferredChannel: DRChannel? {
        guard group.hasMultipleDistricts,
              let preferred = serviceManager.userPreferences.preferredDistrict else { return nil }
        return group.channel(in: preferred)
    }

    private var channel: DRChannel { preferredChannel ?? group.channels.first! }

    private var opensPicker: Bool { group.hasMultipleDistricts && preferredChannel == nil }

    /// A card standing for one channel names its district; one standing for the station
    /// does not.
    private var title: String { preferredChannel?.qualifiedName ?? group.displayTitle }

    /// Artwork and the programme beneath it, as one focusable thing.
    ///
    /// Both inside the button, so focus lifts the whole item rather than the picture alone —
    /// on Apple TV a card and its label move together, and a subtitle left behind while the
    /// artwork grows reads as a glitch.
    ///
    /// That only works with a button style that draws no container of its own.
    /// `tvOSMusicCardButtonStyle` scales and shadows and nothing else, so the subtitle sits
    /// on the page. `.card` would box it in with the artwork, which is the arrangement iOS
    /// deliberately does not use.
    private var item: some View {
        VStack(alignment: .leading, spacing: 10) {
            tvOSChannelCard(channel: channel, titleOverride: title)

            StationCard.Subtitle(
                text: serviceManager.getCurrentProgram(for: channel)?.programmeName ?? "",
                font: .system(size: 18)
            )
            .frame(minHeight: 22)
        }
        .frame(width: 300, alignment: .leading)
    }

    var body: some View {
        Group {
            if opensPicker {
                tvOSVariantMenu(
                    items: group.channels,
                    label: { item },
                    itemTitle: { $0.district ?? $0.name },
                    onSelect: { picked in
                        // Same bargain as on iOS: choosing here says where the listener is,
                        // so the next regional station does not have to ask.
                        if let district = picked.district {
                            serviceManager.userPreferences.rememberDistrict(District(name: district))
                        }
                        onSelect(picked)
                    },
                    panelTitle: String(localized: "Choose a district")
                )
            } else {
                Button {
                    onSelect(channel)
                } label: {
                    item
                }
                .buttonStyle(tvOSMusicCardButtonStyle())
            }
        }
        // Hold select to pin, as on iOS. Without this there was no way to add a favourite
        // outside the Radio tab — so the Favourites shelf stayed empty and looked as though
        // tvOS simply did not have the feature.
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
    }
}
#endif
