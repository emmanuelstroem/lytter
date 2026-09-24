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

    /// How far up the card the glass reaches.
    ///
    /// Deliberately far more than the caption needs. Sized to the text, the gradient had
    /// only the height of two lines to fade across, which reads as the effect starting
    /// just above the words rather than the artwork gradually going behind glass. Over
    /// half the card gives it somewhere to happen.
    var captionFadeHeight: CGFloat { cardHeight * 0.72 }
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

/// Backdrop for a caption sitting on artwork.
///
/// Liquid Glass on iOS 26, an `.ultraThinMaterial` below it — the same shape either way,
/// so the layout does not shift across versions. Both refract what is behind them, which
/// is the point: the card's artwork is arbitrary photography and plain text on it is
/// unreadable often enough to matter.
private struct CaptionBackdrop: View {
    var body: some View {
        glass
            // Masked so the effect fades in from nothing instead of beginning at a hard
            // edge. Without this the band announces itself as a rectangle laid over the
            // artwork; with it the artwork simply becomes unreadable-behind-glass towards
            // the foot of the card.
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.45), location: 0.28),
                        .init(color: .black.opacity(0.85), location: 0.52),
                        .init(color: .black, location: 0.7),
                        .init(color: .black, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var glass: some View {
        if #available(iOS 26.0, *) {
            Rectangle().fill(.clear).glassEffect(.regular, in: .rect)
        } else {
            Rectangle().fill(.ultraThinMaterial)
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
        return currentProgramme?.programmeName ?? String(localized: "Live")
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

    /// A band across the foot of the artwork carrying the station and what is on it.
    ///
    /// The backdrop is not decoration. Artwork is arbitrary photography, so text laid
    /// straight onto it is unreadable often enough to matter — and a band that spans the
    /// card reads at a glance where a small badge did not.
    ///
    /// Both sizes use it, so the shelves differ in scale rather than in kind.
    private func captionBand(titleFont: Font, subtitleLines: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(group.name)
                .font(titleFont)
                .foregroundStyle(.primary)
                .lineLimit(1)
                // Shrinks rather than truncates. The station is the thing being chosen —
                // "P4 Køben…" is a worse card than slightly smaller type.
                .minimumScaleFactor(0.7)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(subtitleLines)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The backdrop is sized independently of the text and laid behind it, so the fade
        // spans the card rather than the caption.
        .background(alignment: .bottom) {
            CaptionBackdrop()
                .frame(height: style.captionFadeHeight)
        }
    }

    private var featuredCard: some View {
        artwork
            .overlay(alignment: .bottom) {
                captionBand(titleFont: .title2.weight(.bold), subtitleLines: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            // Diffuse, barely offset. At radius 7 with y: 4 the shadow hugged the card's
            // straight bottom edge and read as a drawn line rather than a shadow.
            .shadow(color: .black.opacity(0.16), radius: 14, y: 3)
    }

    private var standardCard: some View {
        artwork
            .overlay(alignment: .bottom) {
                captionBand(titleFont: .title3.weight(.semibold), subtitleLines: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.14), radius: 10, y: 2)
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
