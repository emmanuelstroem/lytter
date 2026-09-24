//
//  iOSChannelScheduleSheet.swift
//  lytter
//

import SwiftUI

#if os(iOS)
/// Today's schedule for a channel, presented from the full player's list button.
///
/// The button previously did nothing. A radio app's most obvious "what else is there"
/// question is what is coming up next on the station you are listening to, and the API
/// already answers it — `/schedules/snapshot/{slug}` returns the whole day.
struct iOSChannelScheduleSheet: View {
    let channel: DRChannel
    @ObservedObject var serviceManager: DRServiceManager
    @Environment(\.dismiss) private var dismiss

    @State private var items: [DREpisode] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    ContentUnavailableView(
                        "No schedule",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("DR did not return a schedule for \(channel.title).")
                    )
                } else {
                    List {
                        // Keyed by broadcast, not by episode: the same episode is aired
                        // several times a day and those repeats share one id.
                        ForEach(items, id: \.broadcastID) { episode in
                            ScheduleRow(episode: episode, isOnAir: episode.isCurrentlyPlaying)
                                .listRowBackground(
                                    episode.isCurrentlyPlaying
                                        ? Color.accentColor.opacity(0.12)
                                        : Color.clear
                                )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(channel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            items = await serviceManager.loadSchedule(for: channel)
            isLoading = false
        }
    }
}

/// One programme. The time column is fixed-width so the titles line up, and it is
/// monospaced-digit so the rows do not shift as the digits change.
private struct ScheduleRow: View {
    let episode: DREpisode
    let isOnAir: Bool

    private var startTime: String {
        episode.startDate?.formatted(date: .omitted, time: .shortened) ?? ""
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(startTime)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(isOnAir ? Color.accentColor : .secondary)
                .frame(width: 52, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(episode.cleanTitle())
                    .font(.body)
                    .fontWeight(isOnAir ? .semibold : .regular)
                    .foregroundStyle(.primary)

                if let description = episode.description, !description.isEmpty {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            if isOnAir {
                // Label rather than a bare symbol, so VoiceOver reads it and the symbol
                // stays optically matched to the caption beside it.
                Label("On air", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption.weight(.semibold))
                    .imageScale(.small)
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
#endif
