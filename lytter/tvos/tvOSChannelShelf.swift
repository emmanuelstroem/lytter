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
    var size: tvOSStationCard.Size = .regular
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
                            tvOSStationCard(
                                group: group,
                                size: size,
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

#endif
