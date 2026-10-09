//
//  macOSStationCard.swift
//  lytter
//

import SwiftUI

#if os(macOS)
/// A station, drawn for a window rather than a touch screen or a remote.
///
/// The artwork and caption are the shared `StationCard` pieces — the same glass, the same
/// type scale, the same rule that a card standing for one channel names its district. What
/// is local to macOS is the ergonomics: a hover highlight instead of a remote's focus lift,
/// and a plain `Button` throughout — including for the district choice, which opens as a
/// popover rather than wrapping the card itself in a `Menu`.
///
/// A `Menu` was tried first, as the more native-feeling control for "pick one of ten". It
/// was wrong two ways: styled borderless it still carries its own AppKit control metrics,
/// so it did not size to the artwork the way a `Button` does — P4 and P5 were visibly
/// larger than every other card. And its `label:` is not rendered like ordinary SwiftUI
/// content; before the menu is ever opened the artwork's own `.task` did not reliably run,
/// and once it was opened the label's clipping and caption were not carried along with it
/// — a district picked this way loaded its artwork square, without rounded corners or a
/// name, only after the fact. A `Button` triggering a `.popover` keeps the card itself
/// perfectly ordinary and puts the choice in a separate floating panel instead.
struct macOSStationCard: View {
    let group: GroupedChannel
    var style: StationCardStyle = .standard
    @ObservedObject var serviceManager: DRServiceManager
    let onSelect: (DRChannel) -> Void

    @State private var isHovering = false
    @State private var showingDistrictPicker = false

    private var metrics: StationCardMetrics { .macOS(style) }

    private var preferredChannel: DRChannel? {
        guard group.hasMultipleDistricts,
              let preferred = serviceManager.userPreferences.preferredDistrict else { return nil }
        return group.channel(in: preferred)
    }

    private var channel: DRChannel { preferredChannel ?? group.channels.first! }
    private var opensPicker: Bool { group.hasMultipleDistricts && preferredChannel == nil }
    private var title: String { preferredChannel?.qualifiedName ?? group.displayTitle }

    private var subtitle: String {
        serviceManager.getCurrentProgram(for: channel)?.programmeName ?? String(localized: "Live")
    }

    private var isPlaying: Bool { serviceManager.playingChannel?.id == channel.id }

    /// Whether the playing marker goes beside the name, or leads the programme beneath the
    /// card instead.
    ///
    /// Beside the name only where every name DR broadcasts fits with it: on the standard
    /// card "P4 - Nordjylland" measures 125 points and beside the marker there are 121 —
    /// and widening the card does not help, because the marker grows with it (F44).
    /// The line beneath has the room, and it is where Music marks the playing item too.
    /// `StationCardTests` measures both.
    static func marksPlayingBesideName(_ style: StationCardStyle) -> Bool {
        style == .featured
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            artwork
            caption
        }
        .frame(width: metrics.width, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu {
            if !opensPicker {
                let isFavourite = serviceManager.userPreferences.isFavourite(channel.id)
                Button {
                    serviceManager.userPreferences.toggleFavourite(channel.id)
                } label: {
                    Label(isFavourite ? "Remove from Favourites" : "Add to Favourites",
                          systemImage: isFavourite ? "star.slash" : "star")
                }
            }
            if group.hasMultipleDistricts {
                Menu("Choose district") {
                    districtButtons
                }
            }
        }
    }

    private var artwork: some View {
        Button {
            if opensPicker {
                showingDistrictPicker = true
            } else {
                onSelect(channel)
            }
        } label: {
            cardImage
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingDistrictPicker, arrowEdge: .bottom) {
            districtList
        }
    }

    /// The popover's content: a plain list, the way a Mac already presents "choose one of
    /// these" when it is not a menu bar.
    private var districtList: some View {
        List(group.channels) { district in
            Button(district.district ?? district.name) {
                if let name = district.district {
                    serviceManager.userPreferences.rememberDistrict(District(name: name))
                }
                onSelect(district)
                showingDistrictPicker = false
            }
            .buttonStyle(.plain)
        }
        .frame(width: 220, height: 280)
    }

    private var districtButtons: some View {
        ForEach(group.channels) { district in
            Button(district.district ?? district.name) {
                if let name = district.district {
                    serviceManager.userPreferences.rememberDistrict(District(name: name))
                }
                onSelect(district)
            }
        }
    }

    /// Artwork with the caption over it, or with no picture the station's name across the
    /// whole card (`StationCardFace`).
    private var cardImage: some View {
        StationCardFace(channel: channel, artworkURL: serviceManager.artworkURL(for: channel),
                        title: title, subtitle: subtitle, metrics: metrics) {
            if opensPicker {
                StationCard.PickerCue(metrics: metrics)
            } else if isPlaying, Self.marksPlayingBesideName(style) {
                // Beside the name, not badged onto the artwork — Music marks the
                // playing item in its caption and leaves the picture alone.
                PlayingMark()
                    .font(.system(size: metrics.accessoryFontSize))
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
        .overlay {
            // A hover ring rather than a lift: a window has no depth to raise the card
            // into, and scaling it in place just jitters the grid around it.
            RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(isHovering ? 0.25 : 0), lineWidth: 2)
        }
        .shadow(color: .black.opacity(isHovering ? 0.28 : 0.16),
                radius: isHovering ? 14 : 8, y: isHovering ? 6 : 3)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(title), \(subtitle)"))
        .accessibilityAddTraits(isPlaying ? [.isButton, .isSelected] : .isButton)
    }

    /// What is on the station now, printed beneath the card. Only for `standard`: a
    /// `featured` card already carries the programme in its caption, under the same glass
    /// as the name, so repeating it here would show it twice.
    @ViewBuilder
    private var caption: some View {
        if !style.captionsProgramme {
            StationCard.Subtitle(text: subtitle, metrics: metrics,
                                 showsPlayingMarker: isPlaying && !opensPicker
                                     && !Self.marksPlayingBesideName(style))
                .frame(height: metrics.subtitleFontSize + 4, alignment: .leading)
        }
    }
}
#endif
