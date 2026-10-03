//
//  ConnectionStatusView.swift
//  lytter
//

import SwiftUI

// MARK: - Wording

extension ConnectionProblem {
    /// Says what is wrong in the listener's terms, never in the error's. "You're offline"
    /// and "DR isn't answering" are kept apart on purpose: the first is the listener's to
    /// fix, the second is a wait.
    var title: String {
        switch self {
        case .offline: String(localized: "You're offline")
        case .drUnavailable: String(localized: "DR isn't answering")
        case .streamFailed(let channel): String(localized: "Couldn't play \(channel)")
        }
    }

    /// What happens next. `hasContent` is whether channels are on screen regardless, from
    /// the disk cache or an earlier fetch — in which case they may be out of date, and the
    /// listener should know.
    func message(hasContent: Bool) -> String {
        switch self {
        case .offline:
            hasContent
                ? String(localized: "Showing what was loaded last. It will update when you're back online.")
                : String(localized: "DR's channels will load as soon as you're back online.")
        case .drUnavailable:
            hasContent
                ? String(localized: "Showing what was loaded last. Trying again automatically.")
                : String(localized: "Trying again automatically.")
        case .streamFailed:
            String(localized: "The stream didn't start.")
        }
    }

    var systemImage: String {
        switch self {
        case .offline: "wifi.slash"
        case .drUnavailable: "exclamationmark.icloud"
        case .streamFailed: "speaker.slash"
        }
    }
}

// MARK: - Banner

/// The one inline presentation of a connection problem, over channels that are still on
/// screen. Draws nothing when there is no problem, so a screen can include it
/// unconditionally.
///
/// `playbackOnly` is for the players: there, only what stops audio is worth the space —
/// DR's API being down does not, since the stream comes from elsewhere and plays on.
struct ConnectionBanner: View {
    @ObservedObject var serviceManager: DRServiceManager
    var playbackOnly = false
    /// Whether to offer Try Again. tvOS Now Playing does not: a button there joins the
    /// focus row of transport controls, and Play already restarts a failed stream.
    var showsRetry = true

    private var problem: ConnectionProblem? {
        guard let problem = serviceManager.connectionProblem else { return nil }
        if playbackOnly { return problem.affectsPlayback ? problem : nil }
        // With no channels, `CatalogueStateView` is already saying it, full screen.
        if serviceManager.availableChannels.isEmpty && problem.concernsCatalogue { return nil }
        return problem
    }

    var body: some View {
        if let problem {
            content(for: problem)
                .transition(.opacity)
        }
    }

    private func message(for problem: ConnectionProblem) -> String {
        switch problem {
        case .offline where playbackOnly:
            // In the player the channel list's "showing what was loaded last" means nothing.
            return String(localized: "Playback resumes when you're back online.")
        case .streamFailed where !showsRetry:
            // Without a button, say what does the job of one.
            return String(localized: "The stream didn't start. Press Play to try again.")
        default:
            break
        }
        return problem.message(hasContent: !serviceManager.availableChannels.isEmpty)
    }

    private func content(for problem: ConnectionProblem) -> some View {
        HStack(spacing: Metrics.spacing) {
            Image(systemName: problem.systemImage)
                .font(Metrics.iconFont)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(problem.title)
                    .font(Metrics.titleFont)
                    .foregroundStyle(.primary)
                Text(message(for: problem))
                    .font(Metrics.messageFont)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            if showsRetry {
                Button("Try Again") { serviceManager.retry() }
                    #if !os(tvOS)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    #endif
                    // The button sits `Metrics.padding` in from the banner's corners, which
                    // leaves next to nothing of the radius for it: a capsule (AGENTS.md).
                    .buttonBorderShape(.capsule)
            }
        }
        .padding(Metrics.padding)
        // On a material, so the hierarchical styles above give vibrancy rather than tint.
        .background(.regularMaterial,
                    in: RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
        .accessibilityIdentifier("connection.banner")
    }

    private enum Metrics {
        #if os(tvOS)
        static let spacing: CGFloat = 24
        static let padding: CGFloat = 24
        static let radius: CGFloat = 28   // the tvOS panel radius
        static let iconFont = Font.title2
        static let titleFont = Font.headline
        static let messageFont = Font.callout
        #else
        static let spacing: CGFloat = 12
        static let padding: CGFloat = 12
        static let radius: CGFloat = 16
        static let iconFont = Font.title3
        static let titleFont = Font.subheadline.weight(.semibold)
        static let messageFont = Font.footnote
        #endif
    }
}

// MARK: - In place of the channels

/// What a channel-list screen shows when it has no channels: loading, a connection problem
/// with Try Again, or nothing to list. `content` is drawn once there are channels.
///
/// Every channel list goes through this, on every platform, so none of them can again be
/// the one that shows nothing at all — tvOS Home did, while it waited or after it failed.
struct CatalogueStateView<Content: View>: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ViewBuilder let content: () -> Content

    private var state: CatalogueState {
        CatalogueState.current(hasChannels: !serviceManager.availableChannels.isEmpty,
                               isLoading: serviceManager.isLoading,
                               isWaitingLong: serviceManager.isWaitingLong,
                               problem: serviceManager.connectionProblem)
    }

    var body: some View {
        switch state {
        case .content:
            content()
        case .loading(let isSlow):
            VStack(spacing: 20) {
                ProgressView()
                    .controlSize(.large)
                // Two Texts, not one over a ternary: that would be a String, and a String
                // is never looked up in the catalogue.
                (isSlow ? Text("Still waiting for DR…") : Text("Loading channels..."))
                    .font(.headline)
                    .foregroundStyle(Color.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .problem(let problem):
            ContentUnavailableView {
                Label(problem.title, systemImage: problem.systemImage)
            } description: {
                VStack(spacing: 8) {
                    Text(problem.message(hasContent: false))
                    // Only DR's own error says anything a reader might act on: a status
                    // code, or the 401 that means the API version was retired.
                    if case .drUnavailable(let detail?) = problem {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } actions: {
                if serviceManager.isLoading {
                    ProgressView()
                } else {
                    Button("Try Again") { serviceManager.retry() }
                }
            }
            .accessibilityIdentifier("connection.state")
        case .empty:
            ContentUnavailableView("No channels available",
                                   systemImage: "dot.radiowaves.left.and.right")
        }
    }
}
