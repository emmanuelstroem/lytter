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
    /// How far behind live playback is. `programme` is the one being heard, so progress is
    /// measured at the moment being heard too: against the wall clock, a rewind across a
    /// boundary showed the earlier programme pinned at its end, and a pause kept the bar
    /// moving.
    var secondsBehindLive: TimeInterval = 0

    var body: some View {
        if let programme,
           let start = programme.startDate,
           let end = programme.endDate,
           end > start {
            // Re-renders on its own schedule. A programme runs for half an hour or more,
            // so a tick every ten seconds moves the bar by well under a pixel. Anchored to
            // the programme's start rather than `.now`, so every redraw — once a second
            // while paused — asks for the same schedule.
            //
            // The moment is read when drawn rather than taken from `context.date`, which is
            // the last tick and up to ten seconds old: against an offset that is current, it
            // slid the bar backwards between ticks while paused, and jumped it forward on each.
            TimelineView(.periodic(from: start, by: 10)) { _ in
                content(programme: programme, start: start, end: end,
                        heard: Date.now.addingTimeInterval(-secondsBehindLive))
            }
        }
        // No schedule for this channel: show nothing rather than an empty bar, which is
        // what the old one amounted to.
    }

    private func content(programme: DREpisode, start: Date, end: Date, heard: Date) -> some View {
        let fraction = programme.progress(at: heard) ?? 0
        let remaining = programme.minutesRemaining(at: heard) ?? 0

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
                    // Its own width, always: squeezed between the two times it was clipped.
                    .fixedSize()

                Spacer(minLength: 0)

                Text(end.formatted(date: .omitted, time: .shortened))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(Color.secondaryOnPage)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Programme progress")
        .accessibilityValue(
            remaining > 0
                ? String(localized: "\(remaining) minutes remaining")
                : String(localized: "Ending now")
        )
    }
}

#Preview {
    PlayerProgressView(programme: nil)
        .padding()
}
