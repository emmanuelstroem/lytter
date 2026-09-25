//
//  ChannelShelf.swift
//  lytter
//

import SwiftUI

#if os(iOS)
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

    var body: some View {
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.primary)
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
    /// Nil for a station with no districts, and nil when they have not chosen a region yet
    /// — in both cases there is no region to apply.
    private var preferredChannel: DRChannel? {
        guard group.hasMultipleDistricts,
              let preferred = serviceManager.userPreferences.preferredDistrict else { return nil }
        return group.channel(in: preferred)
    }

    /// The channel this card stands for: their region where there is one, otherwise the
    /// first variant, which is also the one whose artwork is shown.
    private var channel: DRChannel { preferredChannel ?? group.channels.first! }

    /// Whether tapping has a question to ask before it can play anything.
    ///
    /// A station with districts and no chosen region opens the picker; once a region is
    /// remembered the card plays it directly, and says so by naming it.
    private var opensPicker: Bool { group.hasMultipleDistricts && preferredChannel == nil }

    /// What to call this card.
    ///
    /// A station playing the listener's region names it, so that the card says what it will
    /// do — "P4 - København" rather than a bare "P4" that plays something unstated.
    private var title: String { preferredChannel?.qualifiedName ?? group.displayTitle }

    /// The cue that this card asks rather than plays.
    ///
    /// Without it the sheet arrives unannounced: nothing else distinguishes a station that
    /// opens a picker from one that starts playing. VoiceOver already had the hint.
    ///
    /// Added by the caller rather than self-hiding, together with the spacer that pushes
    /// it over: an always-present `Spacer(minLength:)` costs the name ten points of width
    /// even when no chevron follows it, which was enough to truncate "P4 - København" on
    /// the small card that had fitted it before.
    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.bold))
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }

    private var currentProgramme: DREpisode? {
        serviceManager.getCurrentProgram(for: channel)
    }

    private var artworkURL: URL? { serviceManager.artworkURL(for: channel) }

    /// What is on now — for a group, whatever the first district is playing.
    ///
    /// Grouped stations used to caption themselves "10 districts", which named the card's
    /// behaviour rather than its content: every other card says what is on, and P4 said how
    /// many of it there were. The first district is the one whose artwork is already shown,
    /// so the card at least agrees with itself.
    private var subtitle: String {
        currentProgramme?.programmeName ?? String(localized: "Live")
    }

    private var artwork: some View {
        CachedAsyncImage(url: artworkURL,
                         maxPixelSize: ImageCacheService.thumbnailMaxPixelSize) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle().fill(Color(.tertiarySystemFill))
        }
        .frame(width: style.metrics.width, height: style.metrics.height)
        .clipped()
    }

    /// The large card's caption: the station and what is on it, over the artwork.
    ///
    /// The backdrop is not decoration. Artwork is arbitrary photography, so text laid
    /// straight onto it is unreadable often enough to matter.
    /// The caption is shared with tvOS; the chevron is not, because a remote has no
    /// equivalent of a tap that might open a sheet.
    private var caption: some View {
        StationCard.Caption(title: title, subtitle: subtitle, metrics: style.metrics) {
            if opensPicker {
                Spacer(minLength: 4)
                chevron
            }
        }
    }

    private var featuredCard: some View {
        artwork
            .overlay(alignment: .bottom) { caption }
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
        .accessibilityElement(children: .ignore)
        // Composed, not a phrase: Text(verbatim:)'s equivalent for an accessibility
        // label, so "%@, %@" does not land in the catalog for a translator to puzzle over.
        .accessibilityLabel(Text(verbatim: "\(title), \(subtitle)"))
        .accessibilityHint(opensPicker ? "Choose a district" : "Plays this channel")
        .contextMenu {
            // Favouriting needs to know which channel is meant, which is true of a station
            // with no districts and of one playing the listener's region — but not of a
            // card that still stands for ten.
            if !opensPicker {
                let isFavourite = serviceManager.userPreferences.isFavourite(channel.id)
                Button {
                    serviceManager.userPreferences.toggleFavourite(channel.id)
                } label: {
                    Label(isFavourite ? "Remove from Favourites" : "Add to Favourites",
                          systemImage: isFavourite ? "star.slash" : "star")
                }
            }

            // The only way back to the picker once a region is remembered.
            if group.hasMultipleDistricts {
                Button {
                    showingDistrictSheet = true
                } label: {
                    Label("Choose district", systemImage: "list.bullet")
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
