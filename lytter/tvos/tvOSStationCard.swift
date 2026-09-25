//
//  tvOSStationCard.swift
//  lytter
//

import SwiftUI

#if os(tvOS)
/// A station, drawn the way the Music app draws an album.
///
/// Clean artwork with nothing written on it, and beneath it two lines of plain text on the
/// page: what the station is called, and what is on it now.
///
/// Written from nothing rather than adapted from the phone's card, because a television is a
/// different object. It is looked at from three metres with a remote in hand: there is no tap
/// target to advertise and no hover state, and the focused item is already unmistakable
/// because the system raises it. A caption laid over the artwork behind glass solves a
/// problem the phone has and the television does not, and costs the picture to do it.
///
/// Focus is entirely the system's. The button's label is the artwork and nothing else, so
/// `.card` gives the real tvOS treatment — the lift, the parallax as you tilt the remote, the
/// shadow — and the text underneath stays put while the picture moves, which is what every
/// shelf on the platform does.
struct tvOSStationCard: View {

    /// Two sizes, and everything about the card follows from one number.
    enum Size {
        case large
        case regular

        var artwork: CGFloat { self == .large ? 440 : 300 }

        /// Type scales with the artwork, so the same design covers both rows rather than
        /// carrying two sets of hand-picked point sizes.
        var title: CGFloat { artwork * 0.093 }
        var subtitle: CGFloat { artwork * 0.073 }
    }

    let group: GroupedChannel
    var size: Size = .regular
    @ObservedObject var serviceManager: DRServiceManager
    let onSelect: (DRChannel) -> Void

    // MARK: - What the card stands for

    /// The listener's region, when this station broadcasts one and they have chosen it.
    private var preferredChannel: DRChannel? {
        guard group.hasMultipleDistricts,
              let preferred = serviceManager.userPreferences.preferredDistrict else { return nil }
        return group.channel(in: preferred)
    }

    private var channel: DRChannel { preferredChannel ?? group.channels.first! }

    /// Whether choosing this card has a question to ask before it can play anything.
    private var opensPicker: Bool { group.hasMultipleDistricts && preferredChannel == nil }

    /// A card standing for one channel names its district; one standing for the whole
    /// station does not.
    private var title: String { preferredChannel?.qualifiedName ?? group.displayTitle }

    private var subtitle: String {
        serviceManager.getCurrentProgram(for: channel)?.programmeName ?? ""
    }

    private var isPlaying: Bool { serviceManager.playingChannel?.id == channel.id }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            card

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    // Beside the name rather than badged onto the artwork. Music marks the
                    // playing item in its caption and leaves the picture alone.
                    if isPlaying {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: size.subtitle))
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                    }

                    Text(title)
                        .font(.system(size: size.title, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        // Shrinks rather than truncates. The station is the thing being
                        // chosen — "P4 Køben…" is a worse card than slightly smaller type.
                        .minimumScaleFactor(0.6)
                }

                Text(subtitle)
                    .font(.system(size: size.subtitle))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: size.artwork, alignment: .leading)
    }

    @ViewBuilder
    private var card: some View {
        if opensPicker {
            tvOSVariantMenu(
                items: group.channels,
                label: { artwork },
                itemTitle: { $0.district ?? $0.name },
                onSelect: { picked in
                    // Choosing here says where the listener is, so the next regional station
                    // does not have to ask.
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
            // On the button, which is the focusable view. Attached to anything else, tvOS
            // has nothing to hang it on and hold-select does nothing.
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

    /// Deliberately unclipped and unshaped. The card button style rounds and clips its own
    /// label, so shaping the image here would put a second curve inside the system's and the
    /// two would not share a centre.
    private var artwork: some View {
        CachedAsyncImage(url: serviceManager.artworkURL(for: channel),
                         maxPixelSize: ImageCacheService.thumbnailMaxPixelSize) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                Color(white: 0.14)
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: size.artwork * 0.2))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .frame(width: size.artwork, height: size.artwork)
        .clipped()
        .accessibilityLabel(Text(verbatim: "\(title), \(subtitle)"))
    }
}
#endif
