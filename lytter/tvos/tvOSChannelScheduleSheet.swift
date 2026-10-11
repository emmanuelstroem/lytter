//
//  tvOSChannelScheduleSheet.swift
//  lytter
//

import SwiftUI

#if os(tvOS)
/// Today's schedule for a channel, from the player.
///
/// iOS has had this since the full player's list button was wired up; the television had no
/// way to ask at all. "What else is on" is the obvious second question after "what is on",
/// and `/schedules/snapshot/{slug}` already answers it for the whole day.
///
/// Every row can take focus, and that is what makes the schedule scroll. On tvOS a list
/// moves only to bring focus into view, and a read-only schedule has no buttons. This was a
/// `List` on the belief that its rows are focusable by construction; they are not, unless
/// they hold a control, so the schedule sat still however the remote was used. Each row is
/// `.focusable()` now, with a highlight drawn for the focused one, and `TVScrollingUITests`
/// drives it with remote presses so it cannot quietly stop scrolling again.
///
/// A programme that has finished and that DR has a recording of is a button instead, and
/// selecting it plays the recording (F16). Both kinds take focus, so the list scrolls the
/// same over either.
struct tvOSChannelScheduleSheet: View {
    let channel: DRChannel
    @ObservedObject var serviceManager: DRServiceManager
    @Environment(\.dismiss) private var dismiss

    @State private var items: [DREpisode] = []
    @State private var isLoading = true
    /// Why the schedule could not be fetched; see the iOS sheet.
    @State private var failure: ConnectionProblem?
    @FocusState private var focusedRow: String?
    /// The focused row's fill: the colour of the artwork on air, as Now Playing's backdrop
    /// is (`ScheduleTint`), from the station's colour until that has been read. It was a
    /// faint white until then, and the station's own colour with no artwork, which on P3's
    /// light green left the focused row's white text unreadable.
    @State private var tint: ScheduleTint

    init(channel: DRChannel, serviceManager: DRServiceManager) {
        self.channel = channel
        self.serviceManager = serviceManager
        _tint = State(initialValue: .station(channel))
    }

    /// Where focus starts: what is on now, so the schedule opens where the listener is.
    private var onAirRow: String? {
        (items.first(where: \.isCurrentlyPlaying) ?? items.first)?.broadcastID
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Text(channel.qualifiedName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let failure {
                    ContentUnavailableView {
                        Label(failure.title, systemImage: failure.systemImage)
                    } description: {
                        Text("The schedule couldn't be loaded.")
                    } actions: {
                        Button("Try Again") { Task { await load() } }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    Text("No schedule")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Keyed by broadcast, not by episode: the same episode is aired several
                    // times a day and those repeats share one id.
                    ScrollView(.vertical) {
                        // Not lazy: a lazy stack builds only the rows on screen, and focus
                        // cannot be put on a row that does not exist yet — the schedule
                        // opened on the first programme of the day instead of the one on air.
                        // A day is a few dozen rows.
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(items, id: \.broadcastID) { episode in
                                focusableRow(for: episode)
                                    .focused($focusedRow, equals: episode.broadcastID)
                                    // Hold select to pin the show (F33). On the focused
                                    // view, or tvOS has nothing to hang it on.
                                    .contextMenu {
                                        FavouriteShowButton(
                                            episode: episode,
                                            preferences: serviceManager.userPreferences)
                                    }
                                    // One element per row, read as a whole — time, title,
                                    // whether it is on air — rather than piece by piece.
                                    .accessibilityElement(children: .combine)
                                    .accessibilityIdentifier("schedule.row")
                                    .animation(.easeOut(duration: 0.15), value: focusedRow)
                            }
                        }
                        // Room for the focused row's highlight at the top and bottom.
                        .padding(.vertical, 8)
                    }
                    // Where focus lands when it first comes into the list. On the list,
                    // which exists only once the schedule has loaded, so the programme on
                    // air is known by then. Setting the focus from code instead, a moment
                    // after loading, worked on tvOS 26 and not on 18 (B10): there the sheet
                    // was still presenting, the request was dropped, and the focus engine
                    // then put focus on the first row of its own accord.
                    .defaultFocus($focusedRow, onAirRow)
                }
            }
            .padding(48)
            // Fixed, not a maximum. A scrolling list has no intrinsic height, so under
            // maxHeight it claimed none and the whole panel collapsed to its title.
            .frame(width: 1180, height: 820)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        }
        .onExitCommand { dismiss() }
        .task { await load() }
        .task {
            if let artwork = await ScheduleTint.artwork(for: channel, serviceManager: serviceManager) {
                tint = artwork
            }
        }
    }

    /// The row with its focus highlight: a button when there is a recording to play,
    /// otherwise just focusable, so that the list can scroll to it.
    @ViewBuilder
    private func focusableRow(for episode: DREpisode) -> some View {
        let isFocused = focusedRow == episode.broadcastID
        let highlighted = ScheduleRow(
            episode: episode, isOnAir: episode.isCurrentlyPlaying, isHighlighted: isFocused,
            tint: tint, isCatchUp: episode.isCatchUp(at: Date()),
            isPlayingBack: serviceManager.onDemandEpisode?.broadcastID == episode.broadcastID)
            .padding(.horizontal, 20)
            .background(
                // Inset on every side, so it shares no corner with the panel and is not
                // bound to its radius.
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isFocused ? tint.fill : .clear)
            )
        if episode.isCatchUp(at: Date()) {
            Button {
                serviceManager.playOnDemand(episode)
                dismiss()
            } label: {
                highlighted
            }
            .buttonStyle(ScheduleRowButtonStyle())
            .accessibilityHint("Plays the recording")
        } else {
            highlighted.focusable()
        }
    }

    private func load() async {
        isLoading = true
        do {
            items = try await serviceManager.fetchDaySchedule(for: channel)
            failure = nil
        } catch {
            failure = .forFailedRequest(error, isOnline: serviceManager.isOnline)
        }
        isLoading = false
    }
}

/// The row draws its own focus highlight, as the read-only rows do; the system button
/// styles would add a lift and a platter of their own and the two kinds of row would not
/// match.
private struct ScheduleRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
#endif
