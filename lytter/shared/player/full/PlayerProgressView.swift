//
//  PlayerProgressView.swift
//  lytter
//

import SwiftUI

/// How far through the current programme the live broadcast is.
///
/// The bar this replaces was driven by `currentTime`/`totalTime`, a pair of `@State`
/// values initialised to 0 and 100 that nothing in the app ever wrote — so it rendered a
/// permanently empty track with "LIVE" floating over it.
///
/// There is no position to report for a live stream, but there is one for the *programme*
/// on air, and that is the useful number anyway: how much of this you have missed, and
/// how long until the next thing starts. The schedule supplies both ends.
struct PlayerProgressView: View {
    let programme: DREpisode?

    var body: some View {
        if let programme,
           let start = programme.startDate,
           let end = programme.endDate,
           end > start {
            // Re-renders on its own schedule. A programme runs for half an hour or more,
            // so a tick every ten seconds moves the bar by well under a pixel.
            TimelineView(.periodic(from: .now, by: 10)) { context in
                content(programme: programme, start: start, end: end, now: context.date)
            }
        }
        // No schedule for this channel: show nothing rather than an empty bar, which is
        // what the old one amounted to.
    }

    private func content(programme: DREpisode, start: Date, end: Date, now: Date) -> some View {
        let fraction = programme.progress(at: now) ?? 0
        let remaining = programme.minutesRemaining(at: now) ?? 0

        return VStack(spacing: 6) {
            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .tint(Color.accentColor)

            HStack(spacing: 8) {
                Text(start.formatted(date: .omitted, time: .shortened))

                Spacer(minLength: 0)

                // The same idiom as the schedule sheet's "On air" marker.
                Label("LIVE", systemImage: "dot.radiowaves.left.and.right")
                    .imageScale(.small)
                    .fontWeight(.semibold)

                Spacer(minLength: 0)

                Text(end.formatted(date: .omitted, time: .shortened))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(Color.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Programme progress")
        .accessibilityValue(
            remaining > 0
                ? "\(remaining) minutes remaining"
                : "Ending now"
        )
    }
}

#Preview {
    PlayerProgressView(programme: nil)
        .padding()
}
