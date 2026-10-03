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
    /// Lets the screen place focus on a card: each card is tagged `"<title>/<group id>"`,
    /// since the same station can sit on more than one shelf.
    var focus: FocusState<String?>.Binding? = nil

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
                            card(for: group)
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

    @ViewBuilder
    private func card(for group: GroupedChannel) -> some View {
        let card = tvOSStationCard(group: group, style: style,
                                   serviceManager: serviceManager, onSelect: onSelect)
        if let focus {
            card.focused(focus, equals: Self.focusKey(title: title, group: group))
        } else {
            card
        }
    }

    static func focusKey(title: String, group: GroupedChannel) -> String {
        "\(title)/\(group.id)"
    }
}

#endif
