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
struct tvOSChannelScheduleSheet: View {
    let channel: DRChannel
    @ObservedObject var serviceManager: DRServiceManager
    @Environment(\.dismiss) private var dismiss

    @State private var items: [DREpisode] = []
    @State private var isLoading = true
    @FocusState private var focusedRow: String?

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
                                row(for: episode)
                                    .padding(.horizontal, 20)
                                    .background(
                                        // Inset on every side, so it shares no corner with
                                        // the panel and is not bound to its radius.
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(.white.opacity(
                                                focusedRow == episode.broadcastID ? 0.16 : 0))
                                    )
                                    .focusable()
                                    .focused($focusedRow, equals: episode.broadcastID)
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

                }
            }
            .padding(48)
            // Fixed, not a maximum. A scrolling list has no intrinsic height, so under
            // maxHeight it claimed none and the whole panel collapsed to its title.
            .frame(width: 1180, height: 820)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        }
        .onExitCommand { dismiss() }
        .task {
            items = await serviceManager.loadSchedule(for: channel)
            isLoading = false
            // Set once the rows exist. `defaultFocus` is read when the sheet appears, before
            // the schedule has loaded, and focus fell to the first programme of the day.
            try? await Task.sleep(for: .milliseconds(150))
            focusedRow = onAirRow
        }
    }

    /// The time column is fixed-width so the titles line up, and monospaced-digit so the
    /// rows do not shift as the digits change.
    private func row(for episode: DREpisode) -> some View {
        let isOnAir = episode.isCurrentlyPlaying

        return HStack(alignment: .firstTextBaseline, spacing: 20) {
            Text(episode.startDate?.formatted(date: .omitted, time: .shortened) ?? "")
                .font(.body.monospacedDigit())
                .foregroundStyle(isOnAir ? Color.accentColor : Color.secondary)
                .frame(width: 90, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(episode.cleanTitle())
                    .font(.body)
                    .fontWeight(isOnAir ? .semibold : .regular)

                if let description = episode.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            if isOnAir {
                // A label rather than a bare symbol, so VoiceOver reads it.
                Label("On air", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 8)
    }
}
#endif
