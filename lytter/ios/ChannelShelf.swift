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
enum ChannelShelfStyle {
    /// Large card, text laid over the artwork behind a translucent scrim.
    case featured
    /// Smaller card, text underneath.
    case standard

    var cardWidth: CGFloat { self == .featured ? 240 : 148 }
    var cardHeight: CGFloat { self == .featured ? 280 : 148 }
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
struct ChannelShelfCard: View {
    let group: GroupedChannel
    var style: ChannelShelfStyle = .standard
    @ObservedObject var serviceManager: DRServiceManager
    let onTap: (DRChannel) -> Void

    @State private var showingDistrictSheet = false

    private var channel: DRChannel { group.channels.first! }

    private var currentProgramme: DREpisode? {
        serviceManager.getCurrentProgram(for: channel)
    }

    /// Artwork for what is on now, falling back to any cached programme for the channel —
    /// `/schedules/all/now` occasionally returns an entry with no image.
    private var artworkURL: URL? {
        if let url = currentProgramme?.primaryImageURL { return URL(string: url) }
        let cached = serviceManager.getCachedPrograms(for: channel)
        if let url = cached.first(where: { $0.primaryImageURL != nil })?.primaryImageURL {
            return URL(string: url)
        }
        return nil
    }

    private var subtitle: String {
        if group.hasMultipleDistricts {
            return String(localized: "\(group.channels.count) districts")
        }
        return currentProgramme?.cleanTitle() ?? String(localized: "Live")
    }

    private var artwork: some View {
        CachedAsyncImage(url: artworkURL,
                         maxPixelSize: ImageCacheService.thumbnailMaxPixelSize) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle().fill(Color(.tertiarySystemFill))
        }
        .frame(width: style.cardWidth, height: style.cardHeight)
        .clipped()
    }

    /// Caption over the artwork, behind a material scrim.
    ///
    /// The scrim is not decoration: artwork is arbitrary photography, so white text on it
    /// is unreadable often enough to matter. `.ultraThinMaterial` also keeps the caption
    /// legible in both appearances without picking a colour.
    private var featuredCard: some View {
        artwork
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 7, y: 4)
    }

    /// Caption beneath the artwork — the quieter rows.
    private var standardCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            artwork
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 5, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
            .frame(width: style.cardWidth, alignment: .leading)
        }
    }

    var body: some View {
        Button {
            if group.hasMultipleDistricts {
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
        .accessibilityLabel(Text(verbatim: "\(group.name), \(subtitle)"))
        .accessibilityHint(group.hasMultipleDistricts
                           ? "Choose a district"
                           : "Plays this channel")
        .contextMenu {
            if !group.hasMultipleDistricts {
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
