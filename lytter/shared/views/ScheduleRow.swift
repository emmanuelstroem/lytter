//
//  ScheduleRow.swift
//  lytter
//

import SwiftUI

#if os(iOS) || os(tvOS) || os(visionOS)
/// The schedule's colours, from the artwork of the programme on air, as Apple TV's Now
/// Playing takes its backdrop: a fill for the highlighted row, with white on it, and an
/// accent for the marks on the rest.
///
/// With no artwork, or before it has been read, the station's colour brought the same way.
/// The station's colour as it stands is chosen for its tile's name, near-black on P1, P3 and
/// P4, and white on P3's light green did not read.
struct ScheduleTint {
    /// Behind the highlighted row, deep enough for white text: `ArtworkTint.fill`.
    let fill: Color
    /// The on-air time and mark, and the play marks, on the page.
    let accent: Color

    init(_ tint: ArtworkTint) {
        fill = tint.fill
        accent = tint.accent
    }

    static func station(_ channel: DRChannel) -> ScheduleTint {
        ScheduleTint(ArtworkTint(channel.stationColor))
    }

    /// From the programme on air's artwork, or nil when there is none to read.
    static func artwork(for channel: DRChannel, serviceManager: DRServiceManager) async
        -> ScheduleTint? {
        await ArtworkTint.of(ArtworkTint.artworkURL(for: channel, serviceManager: serviceManager))
            .map(ScheduleTint.init)
    }
}

/// One programme in a channel's schedule, the same on every platform with one: the time,
/// the title and its description, and what can be done with it — on air, playing back, or
/// a recording to play.
///
/// The highlighted row is white on the tint's fill. On iPhone, iPad and Vision Pro that is
/// the programme on air; on Apple TV it is the focused row, which is what moves the list.
/// The containers stay each platform's own for that reason: a list on tvOS scrolls only by
/// moving focus (AGENTS.md).
///
/// The time column is fixed-width so the titles line up, and monospaced-digit so the rows do
/// not shift as the digits change. Colours are concrete rather than hierarchical: a catch-up
/// row is a button's label, and there `.primary` resolves against the tint and the titles
/// turn blue.
struct ScheduleRow: View {
    let episode: DREpisode
    let isOnAir: Bool
    let isHighlighted: Bool
    let tint: ScheduleTint
    /// Finished, with a recording to play.
    var isCatchUp = false
    /// The recording playing now.
    var isPlayingBack = false

    private var startTime: String {
        episode.startDate?.formatted(date: .omitted, time: .shortened) ?? ""
    }

    /// Marks on the row: white on the fill, the accent on the page.
    private var markColor: Color { isHighlighted ? .white : tint.accent }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Self.columnSpacing) {
            Text(startTime)
                .font(Self.timeFont.monospacedDigit())
                .foregroundStyle(isHighlighted ? .white : isOnAir ? tint.accent : .secondary)
                .frame(width: Self.timeWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: Self.lineSpacing) {
                Text(episode.cleanTitle())
                    .font(.body)
                    .fontWeight(isOnAir ? .semibold : .regular)
                    .foregroundStyle(isHighlighted ? Color.white : Color.primary)

                if let description = episode.description, !description.isEmpty {
                    Text(description)
                        .font(Self.descriptionFont)
                        .foregroundStyle(isHighlighted ? Color.white.opacity(0.85) : Color.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            if isOnAir {
                // A label rather than a bare symbol, so VoiceOver reads it, and the symbol
                // stays optically matched to the caption beside it.
                Label("On air", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption.weight(.semibold))
                    .imageScale(.small)
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(markColor)
            } else if isPlayingBack {
                Label("Playing", systemImage: "speaker.wave.2.fill")
                    .font(.caption.weight(.semibold))
                    .imageScale(.small)
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(markColor)
            } else if isCatchUp {
                // The affordance, and what VoiceOver hears before the hint.
                Label("Play", systemImage: "play.circle")
                    .font(.title3)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(markColor)
            }
        }
        .padding(.vertical, Self.verticalPadding)
        .accessibilityElement(children: .combine)
    }

    // The television's reading distance; the phone's and the headset's, which share a sheet.
    #if os(tvOS)
    private static let timeFont = Font.body
    private static let descriptionFont = Font.caption
    private static let timeWidth: CGFloat = 90
    private static let columnSpacing: CGFloat = 20
    private static let lineSpacing: CGFloat = 4
    private static let verticalPadding: CGFloat = 8
    #else
    private static let timeFont = Font.subheadline
    private static let descriptionFont = Font.footnote
    private static let timeWidth: CGFloat = 52
    private static let columnSpacing: CGFloat = 12
    private static let lineSpacing: CGFloat = 2
    private static let verticalPadding: CGFloat = 4
    #endif
}
#endif
