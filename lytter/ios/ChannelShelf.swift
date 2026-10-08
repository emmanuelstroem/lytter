//
//  ChannelShelf.swift
//  lytter
//

import SwiftUI

#if os(iOS) || os(visionOS)
/// A horizontally scrolling row of channels under a heading.
///
/// Every row on the home screen is one of these — Favourites, Recently Played, and one per
/// broadcaster — so the sections differ only in their content, not their construction.
///
/// It takes `GroupedChannel` rather than `DRChannel` because a station and a single channel
/// need the same card. A group of one has no districts, so tapping it plays; a group of ten
/// opens the district picker. That is the only behavioural difference, and it falls out of
/// the data rather than needing two views.
/// How prominent a shelf is.
///
/// Apple Music does this too: the top row is larger and captions its artwork, the rows
/// below are smaller and caption beneath. Two sizes is the whole hierarchy — a third would
/// stop reading as "this one matters more".
typealias ChannelShelfStyle = StationCardStyle

extension StationCardStyle {
    /// This platform's sizes. The design itself — proportions, type scale, which glass —
    /// lives in `StationCardMetrics`, shared with tvOS.
    var metrics: StationCardMetrics { .iOS(self) }
}

struct ChannelShelf: View {
    let title: String
    let groups: [GroupedChannel]
    var style: ChannelShelfStyle = .standard
    @ObservedObject var serviceManager: DRServiceManager
    let onChannelTap: (DRChannel) -> Void
    /// Opens the shelf's full list — on Home's *All*, that broadcaster's chip (F54c). No
    /// button without it.
    var onSeeAll: (() -> Void)? = nil

    var body: some View {
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Spacer()
                    if let onSeeAll {
                        Button("See all", action: onSeeAll)
                            .font(.body)
                            .accessibilityIdentifier("seeAll.\(title)")
                    }
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(groups) { group in
                            ChannelShelfCard(
                                group: group,
                                style: style,
                                serviceManager: serviceManager,
                                onTap: onChannelTap
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    // Cards cast a shadow; without this the scroll view clips it.
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

/// Every station in `groups`, as cards in a grid — what the Radio tab was, before Home's
/// chips took it over (F54c). The same card as the shelves, so a station looks the same
/// wherever it is listed; a station with districts is one card, which opens the picker.
struct ChannelGrid: View {
    let groups: [GroupedChannel]
    @ObservedObject var serviceManager: DRServiceManager
    let onChannelTap: (DRChannel) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 16)], spacing: 20) {
            ForEach(groups) { group in
                ChannelShelfCard(group: group, serviceManager: serviceManager, onTap: onChannelTap)
            }
        }
    }
}

/// One card: square artwork, the station's name, and what is on it now.
///
/// The caption's backdrop lives in `shared/views` — tvOS builds its cards from the same
/// piece, so the two platforms cannot drift apart.
struct ChannelShelfCard: View {
    let group: GroupedChannel
    var style: ChannelShelfStyle = .standard
    @ObservedObject var serviceManager: DRServiceManager
    let onTap: (DRChannel) -> Void

    @State private var showingDistrictSheet = false

    /// The listener's own region, when this station broadcasts one for it.
    ///
    /// Nil for a station with no districts, and nil when they have not chosen a region yet.
    private var preferredChannel: DRChannel? {
        guard group.hasMultipleDistricts,
              let preferred = serviceManager.userPreferences.preferredDistrict else { return nil }
        return group.channel(in: preferred)
    }

    /// The channel whose artwork and programme the card shows: their region where there is
    /// one, otherwise the first variant.
    private var channel: DRChannel { preferredChannel ?? group.channels.first! }

    /// Whether tapping asks which district before it plays.
    ///
    /// Always, for a station with districts. It used to play a remembered region straight
    /// away, which left no visible way to hear any other district: someone visiting Fyn
    /// could not get P4 Fyn from the P4 card. The picker lists their region first, so the
    /// usual choice is still one tap. A favourite or a recently played channel is one
    /// district already, and plays directly.
    private var opensPicker: Bool { group.hasMultipleDistricts }

    /// "P4" for the station, "P4 - København" for a card that stands for one district.
    private var title: String { group.displayTitle }

    private var currentProgramme: DREpisode? {
        serviceManager.getCurrentProgram(for: channel)
    }

    private var artworkURL: URL? { serviceManager.artworkURL(for: channel) }

    private var isPlaying: Bool {
        Self.isPlaying(group, loaded: serviceManager.playingChannel, isPlaying: serviceManager.isPlaying)
    }

    /// Whether a card for `group` is the station being heard — any of its districts, for a
    /// card that stands for several, since the card is the station. Not while paused.
    static func isPlaying(_ group: GroupedChannel, loaded: DRChannel?, isPlaying: Bool) -> Bool {
        group.channels.contains { DRServiceManager.isAudible($0, loaded: loaded, isPlaying: isPlaying) }
    }

    /// How far the playing badge sits in from the card's top-right corner, and the badge's
    /// own corner radius: half the card's radius each, so the two curves share a centre
    /// (AGENTS.md, Concentricity). 6 and 6 on the standard card, 7 and 7 on the featured.
    static func playingBadgeInset(_ style: ChannelShelfStyle) -> CGFloat {
        style.metrics.cornerRadius / 2
    }

    /// The playing mark in the card's top-right corner, on dark glass so that it reads over
    /// any artwork. In the corner rather than beside the name, which had no room for it on
    /// the standard card for the longest districts.
    private var playingBadge: some View {
        let inset = Self.playingBadgeInset(style)
        return PlayingMark()
            .font(.system(size: style.metrics.accessoryFontSize))
            // Concrete: inside a Button a hierarchical style resolves against the tint.
            .foregroundStyle(Color.accentColor)
            .padding(inset)
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: inset, style: .continuous))
            .environment(\.colorScheme, .dark)
            .padding(inset)
    }

    /// What is on now — for a group, whatever the listener's region, or failing that the
    /// first district, is playing.
    ///
    /// Grouped stations used to caption themselves "10 districts", which named the card's
    /// behaviour rather than its content: every other card says what is on, and P4 said how
    /// many of it there were. It is the same district whose artwork is shown, so the card
    /// agrees with itself.
    private var subtitle: String {
        currentProgramme?.programmeName ?? String(localized: "Live")
    }

    private var artwork: some View {
        CachedAsyncImage(url: artworkURL,
                         maxPixelSize: ImageCacheService.thumbnailMaxPixelSize) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            // The caption already names the station.
            StationArtworkPlaceholder(channel: channel, showsName: false)
        }
        .frame(width: style.metrics.width, height: style.metrics.height)
        .clipped()
    }

    /// The station, and on a featured card what is on it, over the artwork.
    ///
    /// The chevron says the card asks rather than plays; without it the sheet arrives
    /// unannounced. Added here rather than self-hiding, together with the spacer that pushes
    /// it over: an always-present `Spacer(minLength:)` costs the name width even when no
    /// chevron follows it.
    private var caption: some View {
        StationCard.Caption(title: title, subtitle: subtitle, metrics: style.metrics) {
            if opensPicker {
                Spacer(minLength: 4)
                StationCard.PickerCue(metrics: style.metrics)
            }
        }
    }

    private var featuredCard: some View {
        artwork
            .overlay(alignment: .bottom) { caption }
            .overlay(alignment: .topTrailing) { if isPlaying { playingBadge } }
            .clipShape(RoundedRectangle(cornerRadius: style.metrics.cornerRadius,
                                        style: .continuous))
            // Diffuse, barely offset. At radius 7 with y: 4 the shadow hugged the card's
            // straight bottom edge and read as a drawn line rather than a shadow.
            .shadow(color: .black.opacity(0.16), radius: 14, y: 3)
    }

    /// Named artwork with the programme beneath it — the arrangement Apple Music uses for
    /// its smaller shelves, and the reason these cards are taller than they are wide.
    private var standardCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            artwork
                .overlay(alignment: .bottom) { caption }
                .overlay(alignment: .topTrailing) { if isPlaying { playingBadge } }
                .clipShape(RoundedRectangle(cornerRadius: style.metrics.cornerRadius,
                                            style: .continuous))
                .shadow(color: .black.opacity(0.14), radius: 10, y: 2)

            StationCard.Subtitle(text: subtitle, metrics: style.metrics)
        }
        .frame(width: style.metrics.width, alignment: .leading)
    }

    var body: some View {
        Button {
            if opensPicker {
                showingDistrictSheet = true
            } else {
                onTap(channel)
            }
        } label: {
            switch style {
            case .featured: featuredCard
            case .standard: standardCard
            }
        }
        .buttonStyle(.plain)
        .cardHoverEffect(cornerRadius: style.metrics.cornerRadius)
        .accessibilityElement(children: .ignore)
        // Composed, not a phrase: Text(verbatim:)'s equivalent for an accessibility
        // label, so "%@, %@" does not land in the catalog for a translator to puzzle over.
        .accessibilityLabel(Text(verbatim: "\(title), \(subtitle)"))
        .accessibilityHint(opensPicker ? "Choose a district" : "Plays this channel")
        // The mark is drawn, not read; as in the district sheet, the playing one is selected.
        .accessibilityAddTraits(isPlaying ? .isSelected : [])
        .contextMenu {
            // Favouriting needs to know which channel is meant, so a station with districts
            // is pinned from the picker, where the listener has said which one.
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
        .sheet(isPresented: $showingDistrictSheet) {
            DistrictSelectionSheet(
                groupedChannel: group,
                serviceManager: serviceManager,
                onChannelSelect: onTap
            )
        }
    }
}
#endif
