//
//  iOSFullPlayerSheet.swift
//  lytter
//
//  Created by Emmanuel on 08/08/2025.
//

import SwiftUI
import os

#if os(iOS) || os(visionOS)
struct iOSFullPlayerSheet: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    @Environment(\.dismiss) private var dismiss
    @State private var showingDescriptionSheet: Bool = false
    @State private var showingScheduleSheet: Bool = false
    @State private var showingSleepSheet: Bool = false
    
    // Get the current playing channel from serviceManager
    private var currentChannel: DRChannel? {
        serviceManager.playingChannel
    }
    
    private var channelColor: Color {
        currentChannel?.stationColor ?? .purple
    }
    
    private var infoTitle: String {
        guard let currentChannel = currentChannel else { return String(localized: "No Channel") }
        
        if let track = serviceManager.currentTrack, serviceManager.isHeard(track) {
            let programTitle = serviceManager.getCurrentProgram(for: currentChannel)?.cleanTitle() ?? String(localized: "Live")
            return "\(currentChannel.title) - \(programTitle)"
        } else {
            return currentChannel.title
        }
    }
    
    private var infoSubtitle: String {
        guard let currentChannel = currentChannel else { return String(localized: "No program information") }
        
        if let track = serviceManager.currentTrack, serviceManager.isHeard(track) {
            return track.displayText
        } else if let currentProgram = serviceManager.getCurrentProgram(for: currentChannel) {
            return currentProgram.cleanTitle()
        } else {
            return String(localized: "Live")
        }
    }
    
    /// Rounded up, so a timer with 30 seconds left reads "1 minute" rather than "0".
    private var sleepTimerMinutesRemaining: Int? {
        guard serviceManager.sleepTimer != nil else { return nil }
        return max(Int((serviceManager.sleepTimerRemaining / 60).rounded(.up)), 0)
    }

    private var programDescription: String {
        guard let currentChannel = currentChannel else { return String(localized: "No program information available") }
        
        if let currentProgram = serviceManager.getCurrentProgram(for: currentChannel) {
            return currentProgram.description ?? String(localized: "Live radio programming")
        } else {
            return String(localized: "Live radio programming")
        }
    }
    
    var body: some View {
        // No navigation container. This is a sheet with no title, no toolbar and
        // nothing to navigate to; NavigationView gave it an empty inline bar, and
        // navigationBarBackButtonHidden hid a back button that could never exist.
        ZStack {
            AppBackground()
            
            if let currentChannel = currentChannel {
                // Fixed when it fits, scrolling when it does not. At the largest text sizes
                // on a small iPhone, with the connection banner up, the rows below the
                // artwork need more than the screen's height; centred in too little, they
                // spilled upwards over the top inset and the banner ran over the grab handle.
                // The content is at least as tall as the screen, so the spacers and the
                // artwork share out the room as before, and only grows past it when it must.
                GeometryReader { viewport in
                    ScrollView {
                        AtLeastHeight(height: viewport.size.height) {
                            player(for: currentChannel,
                                   sideBySide: viewport.size.width > viewport.size.height)
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .accessibilityIdentifier("player.scroll")
                }
            } else {
                // No channel playing
                VStack(spacing: 20) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 64, weight: .medium))
                        .foregroundStyle(Color.secondary)
                    
                    Text("No Channel Playing")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        #if os(iOS)
        // Not on visionOS, where the player is not a sheet and is not dragged away: it
        // closes when the window around it is tapped.
        .overlay(alignment: .top) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.6))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
        }
        #endif
        .sheet(isPresented: $showingSleepSheet) {
            iOSSleepTimerSheet(serviceManager: serviceManager)
        }
        .sheet(isPresented: $showingScheduleSheet) {
            if let currentChannel {
                iOSChannelScheduleSheet(channel: currentChannel,
                                        serviceManager: serviceManager)
            }
        }
        .sheet(isPresented: $showingDescriptionSheet) {
            if let currentChannel = currentChannel {
                iOSProgramDescriptionSheet(
                    channel: currentChannel,
                    currentProgram: serviceManager.getCurrentProgram(for: currentChannel),
                    programDescription: programDescription
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    /// The artwork, and every row under it — or beside it, when the player is wider than it
    /// is tall, as on an iPhone on its side.
    ///
    /// Two views that keep their size and only change places, as in Music. It is the layout
    /// that changes, not the views, so turning the phone slides them across rather than
    /// building new ones; and the rows are the same column either way, so nothing in it
    /// moves but the column. Laid out under the artwork on its side, the rows had no height
    /// to spare: the artwork shrank to nothing and the rows still ran off the screen. The
    /// shape is the player's own, not the device's orientation or idiom, so a foldable's
    /// inner display or a short visionOS window is laid out the same (docs/IPHONE-DUO.md).
    private func player(for currentChannel: DRChannel, sideBySide: Bool) -> some View {
        let layout = sideBySide ? AnyLayout(HStackLayout(spacing: 0))
                                : AnyLayout(VStackLayout(spacing: 0))
        return layout {
            // Artwork: a square as wide as the player, or as tall as what is left
            // once everything below has the room it needs. The two halves used to
            // split the height evenly, and on a shorter iPhone the lower half needs
            // more than half — its fixed rows and gaps came out of the artwork, which
            // on an iPhone SE shrank to a stamp. The square is the cap: on a taller
            // phone the artwork is no larger than before, and the gaps below take
            // the rest. Beside the rows it is as tall as the player, and no wider, so
            // the rows have the rest of the width.
            PlayerArtworkView(
                channel: currentChannel,
                currentProgram: serviceManager.getCurrentProgram(for: currentChannel),
                channelColor: channelColor
            )
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: sideBySide ? nil : .infinity)
            .layoutPriority(sideBySide ? 0 : 1)

            // Everything else
            VStack(spacing: 0) {
                // 16, not 30: beside the artwork the rows have only the player's height,
                // and they are the same column under it.
                VStack(spacing: 16) {
                    // Only what stops audio: offline, or this stream failing.
                    ConnectionBanner(serviceManager: serviceManager, playbackOnly: true)
                        .padding(.horizontal, 20)

                    // Info Component
                    // The share control lives inside PlayerInfoView.
                    PlayerInfoView(
                        title: infoTitle,
                        subtitle: infoSubtitle,
                        channel: currentChannel,
                        serviceManager: serviceManager
                    )

                    Group {
                        if serviceManager.onDemandEpisode != nil {
                            OnDemandProgressView(
                                position: serviceManager.onDemandPosition,
                                duration: serviceManager.onDemandDuration,
                                onSeek: { serviceManager.seekOnDemand(to: $0) }
                            )
                        } else {
                            PlayerProgressView(
                                programme: serviceManager.getCurrentProgram(for: currentChannel),
                                secondsBehindLive: serviceManager.secondsBehindLive
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Flexible, with a floor: the fixed 30pt either side of these was
                // what a short screen could least afford.
                Spacer(minLength: 24)

                // Controls Component
                //
                // Skip and Live appear only when the stream has a DVR window
                // (DR's HLS streams); the ICY fallback has nothing to seek in.
                // A recording counts as behind live, so Live leaves it for the
                // channel and skip forward stays on.
                PlayerControlsView(
                    isPlaying: serviceManager.isPlaying,
                    showBackwardButton: serviceManager.canSeek,
                    showForwardButton: serviceManager.canSeek,
                    onBackwardTap: {
                        serviceManager.skip(by: -AudioPlayerService.skipInterval)
                    },
                    onPlayPauseTap: {
                        if let playingChannel = serviceManager.playingChannel {
                            serviceManager.togglePlayback(for: playingChannel)
                        }
                    },
                    onForwardTap: {
                        serviceManager.skip(by: AudioPlayerService.skipInterval)
                    },
                    isForwardEnabled: serviceManager.isBehindLive,
                    onLiveTap: serviceManager.canSeek ? { serviceManager.seekToLive() } : nil,
                    isBehindLive: serviceManager.isBehindLive
                )
                // Fixed heights for the two icon rows. Between the Spacers their frames
                // were whatever was left over, and the transport glyphs are sized from
                // theirs — so larger Dynamic Type text above shrank the play button. The
                // Spacers absorb the difference now. The action glyphs follow Dynamic
                // Type themselves, up to a size this row holds.
                .frame(height: 96)

                Spacer(minLength: 16)

                // Actions Component
                PlayerActionsView(
                    sleepTimerMinutesRemaining: sleepTimerMinutesRemaining,
                    onQuoteTap: {
                        showingDescriptionSheet = true
                    },
                    onListTap: {
                        showingScheduleSheet = true
                    },
                    onSleepTap: {
                        showingSleepSheet = true
                    }
                )
                .frame(height: 56)
            }
            // No maxHeight: a frame that takes whatever height it is offered centres what
            // does not fit in it, upwards as well as down. The spacers fill any spare room.
            .frame(maxWidth: .infinity)
        }
        // Clear of the grab handle, which ends 13pt down. On its side an iPhone has the least
        // height to give, and 20 still clears it.
        .padding(.top, sideBySide ? 20 : 40)
        #if os(visionOS)
        // On iPhone the sheet's safe area keeps the actions off its bottom edge. The
        // visionOS panel has none, and they sat on its edge. They stand clear of the
        // panel's corners, so this is the system's inset inside glass, not a radius sum.
        .padding(.bottom, 24)
        #endif
    }
}

/// Offers its content `height`, and is as tall as the content then asks for, or `height`
/// if that is more. A `ScrollView` offers its content no height at all, and a flexible
/// frame's minimum did not stop the player being laid out in the screen's height and
/// centred in it, overflow and all.
private struct AtLeastHeight: Layout {
    let height: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = subviews.first?.sizeThatFits(ProposedViewSize(width: proposal.width,
                                                                 height: height)) ?? .zero
        return CGSize(width: proposal.width ?? size.width, height: max(height, size.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
                       cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

/// Programme details, presented from the full player.
///
/// Typography follows the HIG's text-style hierarchy rather than fixed sizes, so it
/// scales with Dynamic Type. Metadata uses `Label`, which pairs a symbol with its text
/// and keeps the two optically matched — the previous version placed a default-size
/// `Image` beside body text, and the symbols read as oversized next to it.
struct iOSProgramDescriptionSheet: View {
    let channel: DRChannel?
    let currentProgram: DREpisode?
    let programDescription: String
    @Environment(\.dismiss) private var dismiss

    private var airingTime: String? {
        guard let start = currentProgram?.startDate, let end = currentProgram?.endDate
        else { return nil }
        return "\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))"
    }

    private var durationText: String? {
        guard let duration = currentProgram?.duration, duration > 0 else { return nil }
        // Localised by the formatter rather than hand-built with "min"/"mins".
        return Duration.seconds(duration)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let title = currentProgram?.cleanTitle(), !title.isEmpty {
                        Text(title)
                            .font(.title3.weight(.semibold))
                    }

                    if let airingTime {
                        Text(airingTime)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Duration and categories. `.imageScale(.small)` is what brings the
                    // symbols down to the weight of the text beside them.
                    let categories = currentProgram?.categories ?? []
                    if durationText != nil || !categories.isEmpty {
                        HStack(spacing: 16) {
                            if let durationText {
                                Label(durationText, systemImage: "clock")
                            }
                            if let category = categories.first {
                                Label(category, systemImage: "tag")
                            }
                        }
                        .font(.subheadline)
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                    }

                    Divider()

                    // .primary, not .secondary. As secondary this was legible in light
                    // mode and close to invisible against the sheet in dark mode.
                    Text(programDescription)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .navigationTitle(channel?.title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    iOSFullPlayerSheet(serviceManager: DRServiceManager(), selectionState: SelectionState())
}
#endif
