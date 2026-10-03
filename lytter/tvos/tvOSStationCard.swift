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

    /// Observed directly: a nested ObservableObject does not republish through its owner,
    /// so pinning a district in the picker would update the store and leave its star
    /// undrawn.
    @ObservedObject private var preferences: UserPreferencesService

    init(group: GroupedChannel,
         style: StationCardStyle = .standard,
         serviceManager: DRServiceManager,
         onSelect: @escaping (DRChannel) -> Void) {
        self.group = group
        self.style = style
        self._serviceManager = ObservedObject(wrappedValue: serviceManager)
        self._preferences = ObservedObject(wrappedValue: serviceManager.userPreferences)
        self.onSelect = onSelect
    }

    private var metrics: StationCardMetrics { .tvOS(style) }

    // MARK: - What the card stands for

    /// The listener's region, when this station broadcasts one and they have chosen it.
    private var preferredChannel: DRChannel? {
        guard group.hasMultipleDistricts,
              let preferred = preferences.preferredDistrict else { return nil }
        return group.channel(in: preferred)
    }

    /// The channel whose artwork and programme the card shows: their region where there is
    /// one, otherwise the first variant.
    private var channel: DRChannel { preferredChannel ?? group.channels.first! }

    /// Whether choosing this card asks which district before it plays.
    ///
    /// Always, for a station with districts — the same rule as the phone. Playing a
    /// remembered region straight away left no way to hear any other district, and on the
    /// television not even a hidden one. The picker lists their region first, so the usual
    /// choice is still one click, and a favourite is one district already and plays
    /// directly.
    private var opensPicker: Bool { group.hasMultipleDistricts }

    /// "P4" for the station, "P4 - København" for a card that stands for one district.
    private var title: String { group.displayTitle }

    /// What is on now, as the phone words it — including "Live" when the schedule has
    /// nothing, rather than a blank line under the card.
    private var subtitle: String {
        serviceManager.getCurrentProgram(for: channel)?.programmeName ?? String(localized: "Live")
    }

    private var isPlaying: Bool { serviceManager.isAudible(channel) }

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
                items: group.channels(regionFirst: preferences.preferredDistrict),
                label: { face },
                itemTitle: { $0.district ?? $0.name },
                itemSymbols: symbols(for:),
                itemIsPlaying: serviceManager.isAudible,
                itemMenu: { favouriteButton(for: $0) },
                onSelect: { picked in
                    // Choosing here says where the listener is, so the next regional station
                    // lists it first.
                    if let district = picked.district {
                        preferences.rememberDistrict(District(name: district))
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
            .contextMenu { favouriteButton(for: channel) }
        }
    }

    /// Pins one channel. On the card for a station without districts, and on each district
    /// in the picker — never on a card that stands for ten, which would not say which.
    private func favouriteButton(for channel: DRChannel) -> some View {
        let isFavourite = preferences.isFavourite(channel.id)
        return Button {
            preferences.toggleFavourite(channel.id)
        } label: {
            Label(isFavourite ? "Remove from Favourites" : "Add to Favourites",
                  systemImage: isFavourite ? "star.slash" : "star")
        }
    }

    /// The marks the phone's district sheet shows: their region, a favourite. What is
    /// playing is `PlayingMark`, through `itemIsPlaying`.
    private func symbols(for channel: DRChannel) -> [String] {
        var symbols: [String] = []
        if let region = preferences.preferredDistrict, channel.districtID == region.id {
            symbols.append("location.fill")
        }
        if preferences.isFavourite(channel.id) { symbols.append("star.fill") }
        return symbols
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
                PlayingMark()
                    .font(.system(size: metrics.accessoryFontSize))
                    .foregroundStyle(Color.accentColor)
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
            // The caption already names the station.
            StationArtworkPlaceholder(channel: channel, showsName: false)
        }
        .frame(width: metrics.width, height: metrics.height)
        .clipped()
    }
}
#endif
