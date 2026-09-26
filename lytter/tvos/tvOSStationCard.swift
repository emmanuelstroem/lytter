//
//  tvOSStationCard.swift
//  lytter
//

import SwiftUI

#if os(tvOS)
/// A station on a television: the phone's card, with the platform's focus.
///
/// The same anatomy as iOS, built from the same pieces — the name on glass across the foot
/// of the artwork, the programme under that glass on a featured card and printed beneath a
/// standard one, the chevron on a card that asks before it plays. It was briefly a
/// Music-style card instead, clean artwork with the name printed underneath, and the two
/// platforms stopped looking like one app.
///
/// Focus is still entirely the system's. The button's label is the artwork and its caption,
/// so `.card` gives the real tvOS treatment — the lift, the parallax as you tilt the remote,
/// the shadow — and the caption moves with the picture it belongs to. A standard card's
/// programme is outside the button and stays put, which is what every shelf on the
/// platform does with the text under a card.
struct tvOSStationCard: View {

    let group: GroupedChannel
    var style: StationCardStyle = .standard
    @ObservedObject var serviceManager: DRServiceManager
    let onSelect: (DRChannel) -> Void

    private var metrics: StationCardMetrics { .tvOS(style) }

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

    /// What is on now, as the phone words it — including "Live" when the schedule has
    /// nothing, rather than a blank line under the card.
    private var subtitle: String {
        serviceManager.getCurrentProgram(for: channel)?.programmeName ?? String(localized: "Live")
    }

    private var isPlaying: Bool { serviceManager.playingChannel?.id == channel.id }

    // MARK: - Body

    var body: some View {
        switch style {
        case .featured:
            card
        case .standard:
            // Wider than the phone's 6: focus grows the card about twenty points downward,
            // and at 14 its raised edge landed on the top of the programme's letters.
            VStack(alignment: .leading, spacing: 24) {
                card
                StationCard.Subtitle(text: subtitle, metrics: metrics)
            }
            .frame(width: metrics.width, alignment: .leading)
        }
    }

    @ViewBuilder
    private var card: some View {
        if opensPicker {
            tvOSVariantMenu(
                items: group.channels,
                label: { face },
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
                face
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

    /// The button's label: artwork, and the caption over it.
    ///
    /// Deliberately unclipped and unshaped. The card button style rounds and clips its own
    /// label, so shaping it here would put a second curve inside the system's and the two
    /// would not share a centre. The caption meets the bottom edge with no inset, so the
    /// system's clip is its corner too.
    private var face: some View {
        artwork
            .overlay(alignment: .bottom) { caption }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "\(title), \(subtitle)"))
    }

    private var caption: some View {
        StationCard.Caption(title: title, subtitle: subtitle, metrics: metrics) {
            // Beside the name, where Music marks the playing item, rather than badged onto
            // the artwork. The name's size leaves room for it on the longest station.
            if isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: metrics.accessoryFontSize))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
            if opensPicker {
                Spacer(minLength: 4)
                StationCard.PickerCue(metrics: metrics)
            }
        }
    }

    private var artwork: some View {
        CachedAsyncImage(url: serviceManager.artworkURL(for: channel),
                         maxPixelSize: ImageCacheService.thumbnailMaxPixelSize) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                Color(white: 0.14)
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: metrics.width * 0.2))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .frame(width: metrics.width, height: metrics.height)
        .clipped()
    }
}
#endif
