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
/// A `List` rather than a stack in a `ScrollView`: on tvOS a scroll view only scrolls if it
/// contains something focusable, and a read-only schedule has no buttons. List rows are
/// focusable by construction, and they come with the system's own highlight rather than one
/// drawn here.
struct tvOSChannelScheduleSheet: View {
    let channel: DRChannel
    @ObservedObject var serviceManager: DRServiceManager
    @Environment(\.dismiss) private var dismiss

    @State private var items: [DREpisode] = []
    @State private var isLoading = true

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
                    List(items, id: \.broadcastID) { episode in
                        row(for: episode)
                    }
                    .listStyle(.plain)
                }
            }
            .padding(48)
            // Fixed, not a maximum. A List has no intrinsic height, so under maxHeight it
            // claimed none and the whole panel collapsed to the size of its title.
            .frame(width: 1180, height: 820)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        }
        .onExitCommand { dismiss() }
        .task {
            items = await serviceManager.loadSchedule(for: channel)
            isLoading = false
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
