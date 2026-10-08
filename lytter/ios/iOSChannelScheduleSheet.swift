//
//  iOSChannelScheduleSheet.swift
//  lytter
//

import SwiftUI

#if os(iOS) || os(visionOS)
/// Today's schedule for a channel, presented from the full player's list button.
///
/// The button previously did nothing. A radio app's most obvious "what else is there"
/// question is what is coming up next on the station you are listening to, and the API
/// already answers it — `/schedules/snapshot/{slug}` returns the whole day.
///
/// It is also where catch-up starts (F16). A programme that has finished and that DR has
/// a recording of can be played from here; the sheet then closes onto the player.
struct iOSChannelScheduleSheet: View {
    let channel: DRChannel
    @ObservedObject var serviceManager: DRServiceManager
    @Environment(\.dismiss) private var dismiss

    @State private var items: [DREpisode] = []
    @State private var isLoading = true
    /// Why the schedule could not be fetched. It used to read "No schedule", as if DR had
    /// nothing to list, when the connection was the problem.
    @State private var failure: ConnectionProblem?

    var body: some View {
        NavigationStack {
            Group {
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
                } else if items.isEmpty {
                    ContentUnavailableView(
                        "No schedule",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("DR did not return a schedule for \(channel.title).")
                    )
                } else {
                    ScrollViewReader { proxy in
                        List {
                            // Keyed by broadcast, not by episode: the same episode is aired
                            // several times a day and those repeats share one id.
                            ForEach(items, id: \.broadcastID) { episode in
                                row(for: episode)
                                    // Pin the show this programme belongs to (F33).
                                    .contextMenu {
                                        FavouriteShowButton(
                                            episode: episode,
                                            preferences: serviceManager.userPreferences)
                                    }
                                    .id(episode.broadcastID)
                                    .listRowBackground(
                                        episode.isCurrentlyPlaying
                                            ? Color.accentColor.opacity(0.12)
                                            : Color.clear
                                    )
                            }
                        }
                        .listStyle(.plain)
                        // The day starts at five in the morning; open where the listener is.
                        .onAppear {
                            if let onAir = items.first(where: \.isCurrentlyPlaying) {
                                proxy.scrollTo(onAir.broadcastID, anchor: .center)
                            }
                        }
                    }
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
        .task { await load() }
    }

    /// A catch-up row is a button; the rest are read-only.
    @ViewBuilder
    private func row(for episode: DREpisode) -> some View {
        let isPlayingBack = serviceManager.onDemandEpisode?.broadcastID == episode.broadcastID
        let content = ScheduleRow(episode: episode, isOnAir: episode.isCurrentlyPlaying,
                                  isCatchUp: episode.isCatchUp(at: Date()),
                                  isPlayingBack: isPlayingBack)
        if episode.isCatchUp(at: Date()) {
            Button {
                serviceManager.playOnDemand(episode)
                dismiss()
            } label: {
                content
            }
            .accessibilityHint("Plays the recording")
        } else {
            content
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

/// One programme. The time column is fixed-width so the titles line up, and it is
/// monospaced-digit so the rows do not shift as the digits change.
///
/// Colours are concrete rather than hierarchical: a catch-up row is a button's label, and
/// there `.primary` resolves against the tint and the titles turn blue.
private struct ScheduleRow: View {
    let episode: DREpisode
    let isOnAir: Bool
    /// Finished, with a recording to play.
    var isCatchUp = false
    /// The recording playing now.
    var isPlayingBack = false

    private var startTime: String {
        episode.startDate?.formatted(date: .omitted, time: .shortened) ?? ""
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(startTime)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(isOnAir ? Color.accentColor : Color.secondary)
                .frame(width: 52, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(episode.cleanTitle())
                    .font(.body)
                    .fontWeight(isOnAir ? .semibold : .regular)
                    .foregroundStyle(Color.primary)

                if let description = episode.description, !description.isEmpty {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
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
            } else if isPlayingBack {
                Label("Playing", systemImage: "speaker.wave.2.fill")
                    .font(.caption.weight(.semibold))
                    .imageScale(.small)
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(Color.accentColor)
            } else if isCatchUp {
                // The affordance, and what VoiceOver hears before the hint.
                Label("Play", systemImage: "play.circle")
                    .font(.title3)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
#endif
