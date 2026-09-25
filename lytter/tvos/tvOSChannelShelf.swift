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
    var style: StationCardStyle = .standard
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
                                style: style,
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
    var style: StationCardStyle = .standard

    private var metrics: StationCardMetrics { .tvOS(style) }
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

    /// The button is the artwork and nothing else, so `.card` lifts a picture rather than a
    /// picture with a caption stuck to it — which is what Apple's own shelves do. The
    /// programme is printed underneath, outside the button, and stays put while the card
    /// lifts.
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            card

            // A featured card carries the programme under its own glass, so there is nothing
            // to print beneath it.
            if !style.captionsProgramme {
                StationCard.Subtitle(
                    text: serviceManager.getCurrentProgram(for: channel)?.programmeName ?? "",
                    metrics: metrics
                )
                .frame(minHeight: 22)
            }
        }
        .frame(width: metrics.width, alignment: .leading)
    }

    @ViewBuilder
    private var card: some View {
        let artwork = tvOSChannelCard(channel: channel, metrics: metrics, titleOverride: title)

        if opensPicker {
            tvOSVariantMenu(
                items: group.channels,
                label: { artwork },
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
                artwork
            }
            .buttonStyle(.card)
            // On the button itself, not on a container around it. tvOS attaches a context
            // menu to a focusable view; hung on the enclosing Group it had nothing to
            // attach to, which is why hold-select did nothing.
            .contextMenu {
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
