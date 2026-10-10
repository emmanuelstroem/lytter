//
//  tvOSNowPlayingView.swift
//  lytter
//

import SwiftUI
import os
#if os(iOS) || os(tvOS)
import UIKit
#endif
#if os(tvOS)
import GroupActivities
#endif

#if os(tvOS)

// MARK: - Now Playing
/// Artwork and what is on air across the top, the progress bar and the controls along the
/// bottom, on a backdrop coloured from the artwork: the arrangement Spotify uses on Apple TV.
///
/// Left alone for a few seconds, the screen dims to a small card in the corner — artwork,
/// station, programme, track — as Spotify's does, so a radio left playing on the television
/// is a quiet picture rather than a wall of controls. Any press of the remote brings the
/// controls back.
///
/// This screen hid its controls once before, and the way it did that was taken out: a
/// gesture recognizer on the window that saw only the back button, direction presses that
/// moved focus between buttons nobody could see, and a helper reaching for a tab bar that
/// had become a sidebar. Waking now goes through focus instead of around it. While the
/// screen is dim the controls are disabled, so nothing hidden can take focus, and the one
/// thing that can is a full-screen target whose every command — select, a direction, Menu,
/// Play/Pause — wakes the screen. A press that wakes it does nothing else, except
/// Play/Pause, which also plays or pauses, since that is what the button says.
struct tvOSNowPlayingView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @State private var showingInfoSheet = false
    @State private var showingScheduleSheet = false

    /// Dimmed to the corner card.
    @State private var isIdle = false
    /// Bumped by every press of the remote; the countdown to dimming restarts from each.
    @State private var activity = 0
    @FocusState private var focus: Focus?
    /// Counts the times the screen has woken; see where the player is placed in `body`.
    @State private var wakings = 0
    /// The control that had focus when the screen dimmed, given focus again on waking.
    @State private var lastControl: tvOSNowPlayingControls.ControlButton = .play
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    enum Focus: Hashable {
        case control(tvOSNowPlayingControls.ControlButton)
        /// The full-screen target that exists only while the screen is dim.
        case wake
    }

    /// How long the remote has to be left alone before the screen dims. Under test it never
    /// dims unless a test asks for it: the others pause on this screen longer than this.
    private static var idleDelay: Duration? {
        #if DEBUG
        if UITestFixtures.isActive { return UITestFixtures.nowPlayingIdleDelay }
        #endif
        return .seconds(8)
    }

    var body: some View {
        ZStack {
            if let channel = serviceManager.playingChannel {
                tvOSNowPlayingBackground(channel: channel, serviceManager: serviceManager)
                    .ignoresSafeArea()

                Color.black
                    .opacity(isIdle ? 0.5 : 0)
                    .ignoresSafeArea()

                player(for: channel)
                    .opacity(isIdle ? 0 : 1)
                    .disabled(isIdle)
                    // Built afresh on waking. Disabled and enabled again, the controls
                    // kept focus but stopped telling accessibility which of them had it.
                    .id(wakings)

                // Built only while dim. Kept in place at no opacity, it was still in the
                // accessibility tree, hidden or not.
                if isIdle {
                    tvOSNowPlayingIdleCard(channel: channel, serviceManager: serviceManager)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .bottomLeading)
                        .transition(.opacity)
                }

                // Always here, and enabled only while dim. Removed on waking while it had
                // focus, it left the focus engine with nothing: the control given focus
                // drew itself focused, and the remote moved nothing. Disabled instead,
                // it makes the engine move focus on, as disabling the controls does when
                // the screen dims.
                wakeTarget(for: channel)
                    .disabled(!isIdle)
            } else {
                tvOSEmptyState(serviceManager: serviceManager)
            }
        }
        // Slow to dim, quick to wake: the screen settling should be hard to notice, and
        // the controls coming back should feel like an answer to the press.
        .animation(.easeInOut(duration: isIdle ? 1.2 : 0.3), value: isIdle)
        // Play first, as in Spotify: it is what the screen is for.
        .defaultFocus($focus, .control(.play))
        .task(id: activity) { await dimWhenLeftAlone() }
        .onChange(of: focus) { _, newFocus in
            switch newFocus {
            case .control(let control):
                lastControl = control
                noteActivity()
            case .wake:
                break
            case nil:
                // Focus has left the screen — to the sidebar, most likely — and nothing
                // should stay dim behind it. Not at once: focus passes through nil for a
                // moment as the screen dims and its controls are disabled.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    if focus == nil { isIdle = false }
                }
            }
        }
        .onMoveCommand { _ in noteActivity() }
        .onChange(of: showingInfoSheet) { _, _ in noteActivity() }
        .onChange(of: showingScheduleSheet) { _, _ in noteActivity() }
        .sheet(isPresented: $showingScheduleSheet) {
            if let ch = serviceManager.playingChannel {
                tvOSChannelScheduleSheet(channel: ch, serviceManager: serviceManager)
            }
        }
        .sheet(isPresented: $showingInfoSheet) {
            if let ch = serviceManager.playingChannel {
                tvOSNowPlayingInfoSheet(
                    channel: ch,
                    program: serviceManager.getCurrentProgram(for: ch),
                    track: serviceManager.currentTrack
                )
                .background(.clear)
            }
        }
    }

    /// Artwork and the words beside it, then the progress bar and the controls across the
    /// width of the screen.
    private func player(for channel: DRChannel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            HStack(alignment: .center, spacing: 64) {
                tvOSNowPlayingArtwork(channel: channel, serviceManager: serviceManager,
                                      side: 420, cornerRadius: 24)
                    .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 20)

                details(for: channel)
            }

            Spacer(minLength: 40)

            programmeProgress(for: channel)

            tvOSNowPlayingControls(
                serviceManager: serviceManager,
                showingInfoSheet: $showingInfoSheet,
                showingScheduleSheet: $showingScheduleSheet,
                channel: channel,
                focus: $focus
            )
            .padding(.top, 28)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 10)
    }

    /// What is playing, beside the artwork.
    private func details(for channel: DRChannel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // The station leads. On live radio it is the thing you chose; the programme is
            // what happens to be on it, which is the opposite of an album and a track.
            Text(channel.qualifiedName)
                .font(.system(size: 58, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let programme = serviceManager.getCurrentProgram(for: channel)?.programmeName,
               !programme.isEmpty {
                Text(programme)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
                    .padding(.top, 10)
            }

            // Scrolls when it is longer than the column (B11). Artist and title together
            // run long, and cut off with an ellipsis the end of the title was lost.
            if let track = serviceManager.currentTrack {
                MarqueeText(text: track.displayText, font: .system(size: 26),
                            leftFade: 24, rightFade: 24, startDelay: 2)
                    .accessibilityID("nowPlaying.track")
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 14)
            }

            // Not focusable, so it never joins the row of controls below; Play is the retry.
            ConnectionBanner(serviceManager: serviceManager, playbackOnly: true,
                             showsRetry: false)
                .padding(.top, 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
    }

    /// The only thing that can take focus while the screen is dim, and the whole screen,
    /// so that wherever the remote points, it points here.
    private func wakeTarget(for channel: DRChannel) -> some View {
        Button(action: wake) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(tvOSWakeButtonStyle())
        .focused($focus, equals: .wake)
        .onMoveCommand { _ in wake() }
        // Menu wakes rather than leaving: a viewer who cannot see the controls has not
        // yet decided to go anywhere.
        .onExitCommand(perform: wake)
        .onPlayPauseCommand {
            serviceManager.togglePlayback(for: channel)
            wake()
        }
        // Never read out. The screen does not dim while VoiceOver runs, so there is never
        // anything for it to wake. Its hiding is fixed, not tied to dimming: an element
        // whose hiding changed stopped reporting focus to XCUITest.
        .accessibilityHidden(true)
        .ignoresSafeArea()
    }

    // MARK: Idle

    private func noteActivity() {
        activity &+= 1
    }

    /// Dims the screen once `idleDelay` passes with no press of the remote. Restarted by
    /// every press, which is what cancels the one before.
    private func dimWhenLeftAlone() async {
        guard let delay = Self.idleDelay else { return }
        try? await Task.sleep(for: delay)
        guard !Task.isCancelled, mayDim else { return }
        isIdle = true
        // The focused control has just been disabled; the target is the one place focus can
        // go. Asked until it is there, as Home's launch focus is: a request made while the
        // focus engine is still moving can be dropped (B10).
        await place(.wake)
    }

    /// Not with VoiceOver, which reads the controls, nor over a sheet, nor while focus is
    /// outside the screen — in the sidebar, where the viewer is busy elsewhere.
    private var mayDim: Bool {
        !isIdle && !voiceOverEnabled && !showingInfoSheet && !showingScheduleSheet
            && focus != nil && serviceManager.playingChannel != nil
    }

    private func wake() {
        noteActivity()
        guard isIdle else { return }
        isIdle = false
        wakings &+= 1
        let control = lastControl
        Task { @MainActor in
            await place(.control(control))
            // The control it had may have gone while the screen was dim — Live, once
            // playback caught up, or SharePlay, once the call ended.
            if focus == nil { await place(.control(.play)) }
        }
    }

    private func place(_ target: Focus) async {
        for _ in 0..<10 {
            focus = target
            try? await Task.sleep(for: .milliseconds(50))
            if focus == target { return }
        }
    }

    /// How far through the programme the broadcast is, with the hour it started and the hour
    /// it ends.
    ///
    /// Live radio has nothing to scrub, so this is a read-out rather than a control — which
    /// is also why it is not focusable.
    ///
    /// Driven by a `TimelineView` rather than a timer of its own: the bar only has to be
    /// right to the nearest minute on a screen someone is looking at, and a view that
    /// redraws itself needs no state to keep in sync.
    @ViewBuilder
    private func programmeProgress(for channel: DRChannel) -> some View {
        if serviceManager.onDemandEpisode != nil {
            onDemandProgress
        } else if let programme = serviceManager.getCurrentProgram(for: channel),
           let start = programme.startDate,
           let end = programme.endDate {
            // Anchored to the programme's start rather than `.now`, so every redraw asks
            // for the same schedule; and measured at the moment being heard, since
            // `getCurrentProgram` picks the programme for that moment. That moment is read
            // when drawn: `context.date` is the last tick, up to 30 s old, and against a
            // current offset it slid the bar backwards between ticks while paused.
            TimelineView(.periodic(from: start, by: 30)) { _ in
                let heard = Date.now.addingTimeInterval(-serviceManager.secondsBehindLive)
                VStack(alignment: .leading, spacing: 12) {
                    tvOSProgressBar(fraction: programme.progress(at: heard) ?? 0)

                    HStack {
                        Text(start.formatted(date: .omitted, time: .shortened))
                        Spacer()
                        Text(end.formatted(date: .omitted, time: .shortened))
                    }
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()
                }
            }
        }
    }

    /// A recording's position (F16): elapsed and remaining rather than the hours it aired.
    /// Still a read-out — skip moves through it — so that the row of controls stays the
    /// only thing that takes focus.
    private var onDemandProgress: some View {
        let position = serviceManager.onDemandPosition
        let duration = max(serviceManager.onDemandDuration, 1)
        return VStack(alignment: .leading, spacing: 12) {
            tvOSProgressBar(fraction: min(position / duration, 1))

            HStack {
                Text(verbatim: PlaybackTime.format(position))
                Spacer()
                Label("On demand", systemImage: "clock.arrow.circlepath")
                Spacer()
                Text(verbatim: "−\(PlaybackTime.format(max(duration - position, 0)))")
            }
            .font(.system(size: 20))
            .foregroundStyle(.white.opacity(0.6))
            .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Position")
        .accessibilityValue(PlaybackTime.format(position))
    }
}

/// A thin bar across the screen, filled as far as `fraction`.
private struct tvOSProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule()
                    .fill(.white)
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 6)
    }
}

/// No lift, no platter, no highlight: the wake target is invisible, and only has to be
/// somewhere for focus to be.
private struct tvOSWakeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .focusEffectDisabled()
    }
}

// MARK: - Idle Card
/// What the screen dims to: the artwork, small, and what is on air beside it, in the corner.
struct tvOSNowPlayingIdleCard: View {
    let channel: DRChannel
    @ObservedObject var serviceManager: DRServiceManager

    var body: some View {
        HStack(alignment: .center, spacing: 28) {
            // Stands free on the backdrop, with no shape around it to share a corner with.
            tvOSNowPlayingArtwork(channel: channel, serviceManager: serviceManager,
                                  side: 160, cornerRadius: 12)

            VStack(alignment: .leading, spacing: 6) {
                Text(channel.qualifiedName)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let programme = serviceManager.getCurrentProgram(for: channel)?.programmeName,
                   !programme.isEmpty {
                    Text(programme)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }

                if let track = serviceManager.currentTrack {
                    MarqueeText(text: track.displayText, font: .system(size: 22),
                                leftFade: 16, rightFade: 16, startDelay: 2)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
        }
        .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("nowPlaying.idle")
    }
}

// MARK: - Backdrop
/// A wash of the artwork's own colour, darkening to black at the foot of the screen where
/// the controls sit, with the artwork itself blurred faintly into it.
struct tvOSNowPlayingBackground: View {
    let channel: DRChannel
    @ObservedObject var serviceManager: DRServiceManager
    @State private var tint: Color = .black

    private var artworkURL: URL? {
        guard let program = serviceManager.getCurrentProgram(for: channel),
              let urlString = program.landscapeImageURL ?? program.primaryImageURL
        else { return nil }
        return URL(string: urlString)
    }

    var body: some View {
        ZStack {
            Color.black

            LinearGradient(colors: [tint, tint.opacity(0.6), .black],
                           startPoint: .topLeading, endPoint: .bottom)

            if let url = artworkURL {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(1.15)
                        .blur(radius: 80)
                        .opacity(0.3)
                } placeholder: {
                    Color.clear
                }
            }

            // Legibility for the progress row and the controls at the bottom.
            LinearGradient(colors: [.clear, .black.opacity(0.6)],
                           startPoint: .center, endPoint: .bottom)
        }
        .animation(.easeInOut(duration: 0.6), value: tint)
        // From the square artwork, as the schedule's highlight is, so the two match.
        .task(id: tintURL) {
            tint = await ArtworkTint.of(tintURL)?.backdrop ?? channel.stationColor.opacity(0.6)
        }
    }

    private var tintURL: URL? {
        ArtworkTint.artworkURL(for: channel, serviceManager: serviceManager)
    }
}

// MARK: - Artwork
/// The programme's artwork, or the station's when it has none.
struct tvOSNowPlayingArtwork: View {
    let channel: DRChannel
    @ObservedObject var serviceManager: DRServiceManager
    let side: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        CachedAsyncImage(url: ArtworkTint.artworkURL(for: channel, serviceManager: serviceManager)) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            StationArtworkPlaceholder(channel: channel)
        }
        .frame(width: side, height: side)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}


// MARK: - Controls Row
/// Transport in the middle, as Spotify has it; what the programme is on the left, and what
/// else there is to do on the right. Plain glyphs until focused, when a white disc comes up
/// behind the one with focus. Play is always the disc, being what the screen is for.
struct tvOSNowPlayingControls: View {
    @ObservedObject var serviceManager: DRServiceManager
    @Binding var showingInfoSheet: Bool
    @Binding var showingScheduleSheet: Bool
    let channel: DRChannel
    var focus: FocusState<tvOSNowPlayingView.Focus?>.Binding
    @StateObject private var groupState = GroupStateObserver()

    enum ControlButton: Hashable { case info, back, play, forward, shareplay, schedule, live }

    var body: some View {
        ZStack {
            HStack(spacing: 24) {
                Button {
                    showingInfoSheet = true
                } label: {
                    GlyphLabel(systemImage: "info.circle")
                }
                .buttonStyle(tvOSMusicCardButtonStyle())
                .focused(focus, equals: .control(.info))

                Spacer(minLength: 0)

                // Always on the row, so that the row is the same every time; usable only
                // while there is a FaceTime call to share into, since with none it could do
                // nothing at all. It used to appear only then, and its absence read as the
                // feature having gone.
                Button {
                    if let ch = serviceManager.playingChannel {
                        Task { await SharePlayCoordinator.start(ch) }
                    }
                } label: {
                    GlyphLabel(systemImage: "shareplay")
                }
                .buttonStyle(tvOSMusicCardButtonStyle())
                .disabled(!groupState.isEligibleForGroupSession)
                .focused(focus, equals: .control(.shareplay))
                .accessibilityLabel("SharePlay")

                // What else is on. iOS has had this from the full player since the list
                // button was wired up; the television could not ask at all.
                Button {
                    showingScheduleSheet = true
                } label: {
                    GlyphLabel(systemImage: "list.bullet")
                }
                .buttonStyle(tvOSMusicCardButtonStyle())
                .focused(focus, equals: .control(.schedule))
                .accessibilityLabel("Schedule")

                if serviceManager.isBehindLive {
                    Button {
                        serviceManager.seekToLive()
                        // The button goes once playback is live; hand focus somewhere that
                        // stays.
                        focus.wrappedValue = .control(.play)
                    } label: {
                        LiveLabel()
                    }
                    .buttonStyle(tvOSMusicCardButtonStyle())
                    .focused(focus, equals: .control(.live))
                    .accessibilityLabel("Jump to live")
                }
            }

            HStack(spacing: 40) {
                // Skip is always there, and works when the stream has a DVR window to move
                // in; DR's HLS streams do, the ICY fallback does not. It used to appear only
                // then, and the row changed shape from one station to the next.
                Button {
                    serviceManager.skip(by: -AudioPlayerService.skipInterval)
                } label: {
                    GlyphLabel(systemImage: "gobackward.15")
                }
                .buttonStyle(tvOSMusicCardButtonStyle())
                .disabled(!serviceManager.canSeek)
                .focused(focus, equals: .control(.back))
                .accessibilityLabel("Skip back 15 seconds")

                Button {
                    serviceManager.togglePlayback(for: channel)
                } label: {
                    PlayPauseLabel(isPlaying: serviceManager.isPlaying)
                }
                .buttonStyle(tvOSMusicCardButtonStyle())
                .focused(focus, equals: .control(.play))
                .accessibilityLabel(serviceManager.isPlaying ? "Pause" : "Play")

                // Also off at the live edge, where there is nothing ahead.
                Button {
                    serviceManager.skip(by: AudioPlayerService.skipInterval)
                } label: {
                    GlyphLabel(systemImage: "goforward.15")
                }
                .buttonStyle(tvOSMusicCardButtonStyle())
                .disabled(!serviceManager.canSeek || !serviceManager.isBehindLive)
                .focused(focus, equals: .control(.forward))
                .accessibilityLabel("Skip forward 15 seconds")
            }
        }
    }

    /// A glyph on its own, with a white disc behind it while it has focus, and faint while
    /// it cannot be used.
    private struct GlyphLabel: View {
        let systemImage: String
        @Environment(\.isFocused) private var isFocused
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(isFocused ? Color.black
                                 : Color.white.opacity(isEnabled ? 0.85 : 0.3))
                .frame(width: 72, height: 72)
                .background(isFocused ? Color.white : Color.clear, in: Circle())
                .focusAnimation(value: isFocused)
        }
    }

    /// The way back to live, shown only while behind it.
    private struct LiveLabel: View {
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            HStack(spacing: 10) {
                Circle().fill(Color.red).frame(width: 12, height: 12)
                Text("Live").font(.system(size: 26, weight: .semibold))
            }
            .foregroundStyle(isFocused ? Color.black : Color.white.opacity(0.85))
            .padding(.horizontal, 24)
            .frame(height: 72)
            .background(isFocused ? Color.white : Color.clear, in: Capsule())
            .focusAnimation(value: isFocused)
        }
    }

    /// Always a white disc; focus brings it up a little brighter and lifts it, through the
    /// button style.
    private struct PlayPauseLabel: View {
        let isPlaying: Bool
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(Color.black)
                .offset(x: isPlaying ? 0 : 3)
                .frame(width: 100, height: 100)
                .background(Color.white.opacity(isFocused ? 1 : 0.85), in: Circle())
                .shadow(color: .white.opacity(isFocused ? 0.45 : 0), radius: 18, x: 0, y: 0)
                .focusAnimation(value: isFocused)
        }
    }
}

// MARK: - Empty State
struct tvOSEmptyState: View {
    @ObservedObject var serviceManager: DRServiceManager

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 40) {
                ZStack {
                    Circle().fill(.ultraThinMaterial).frame(width: 120, height: 120)
                    Image(systemName: "play.circle.fill").font(.system(size: 60)).foregroundStyle(.white)
                }
                VStack(spacing: 16) {
                    Text("Nothing Playing").font(.largeTitle).fontWeight(.bold).foregroundStyle(.white)
                    Text("Select a channel to start listening").font(.title3).foregroundStyle(.white.opacity(0.7))
                }
                if let first = serviceManager.availableChannels.first {
                    Button("Play \(first.title)") { serviceManager.playChannel(first) }
                        .font(.headline).fontWeight(.semibold).foregroundStyle(.black)
                        .padding(.horizontal, 40).padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
                        .buttonStyle(.plain).focusable()
                }
            }
        }
    }
}

// MARK: - Info Sheet
struct tvOSNowPlayingInfoSheet: View {
    let channel: DRChannel
    let program: DREpisode?
    let track: DRTrack?

    private var artworkURL: URL? {
        guard let s = program?.primaryImageURL ?? program?.landscapeImageURL else { return nil }
        return URL(string: s)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {

            // Left: Program artwork with channel pill overlay
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(url: artworkURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    StationArtworkPlaceholder(channel: channel)
                }
                .frame(width: 340, height: 340)
                // Dim layer — sits on the image, below the pill
                Color.black.opacity(0.35)
                    .frame(width: 340, height: 340)
            }
            .frame(width: 340, height: 340)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 6) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 13, weight: .bold))
                    Text(channel.title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(12)
            }
            .padding(44)

            // Divider
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(width: 1)
                .padding(.vertical, 44)

            // Right: Info. The title and the track stay put; only the description
            // scrolls, and it scrolls with the remote — see `tvOSScrollingText`. This was a
            // ScrollView with nothing focusable in it, which tvOS never scrolls.
            VStack(alignment: .leading, spacing: 0) {

                // Program title — hero text
                if let title = program?.cleanTitle(), !title.isEmpty {
                    Text(title)
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .padding(.top, 10)
                }

                // Now playing track pill
                if let t = track {
                    HStack(spacing: 7) {
                        Image(systemName: "music.note")
                            .font(.system(size: 12, weight: .bold))
                        Text(t.displayText)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.15), in: Capsule())
                    .padding(.top, 18)
                }

                // Description
                if let desc = program?.description, !desc.isEmpty {
                    tvOSScrollingText(text: desc)
                        .accessibilityIdentifier("info.description")
                        .padding(.top, 24)
                }
            }
            .padding(.top, 44)
            .padding(.leading, 32)
            .padding(.trailing, 44)
            .padding(.bottom, 44)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: 1260)
        .frame(minHeight: 340 + 88)
        // A ceiling, so a long description scrolls inside the sheet instead of growing it
        // past the screen.
        .frame(maxHeight: 760)
        .background(.clear)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .shadow(color: .black.opacity(0.6), radius: 80, x: 0, y: 40)
        .padding(60)
    }
}
#endif
