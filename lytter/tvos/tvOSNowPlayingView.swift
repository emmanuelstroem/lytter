//
//  tvOSNowPlayingView.swift
//  lytter
//

import SwiftUI
import os
import UIKit
import CoreImage
#if canImport(GroupActivities)
import GroupActivities
#endif

#if os(tvOS)

// MARK: - Now Playing
/// The controls are always on screen.
///
/// They used to fade out after five seconds and come back on any remote input, which took a
/// pass-through gesture recognizer attached to the window and a helper that reached into
/// UIKit to hide the tab bar. It did not work: the controls came back only on the back
/// button, direction presses moved focus instead of waking anything, and the tab-bar helper
/// was reaching for a tab bar that no longer exists now that navigation is a sidebar.
///
/// Nothing replaced it. A row of three buttons is not worth hiding, and every part of the
/// machinery that hid them was a way for focus to go wrong.
struct tvOSNowPlayingView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @State private var showingInfoSheet = false
    @State private var showingScheduleSheet = false

    /// Artwork on the left, everything about it on the right — the arrangement the Music app
    /// uses on Apple TV, and a better fit for a television than the centred stack this
    /// replaces. A 16:9 screen has width to spare and very little height; stacking artwork,
    /// title, track and controls down the middle spent the scarce dimension and left two
    /// wide empty margins.
    var body: some View {
        ZStack {
            if let channel = serviceManager.playingChannel {
                tvOSNowPlayingBackground(channel: channel, serviceManager: serviceManager)
                    .ignoresSafeArea()

                HStack(alignment: .center, spacing: 72) {
                    tvOSNowPlayingArtworkCard(channel: channel, serviceManager: serviceManager)

                    details(for: channel)
                }
                .padding(.horizontal, 90)
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
            } else {
                tvOSEmptyState(serviceManager: serviceManager)
            }
        }
    }

    /// The right-hand column: what is playing, how far through it is, and what you can do.
    private func details(for channel: DRChannel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            // The station leads. On live radio it is the thing you chose; the programme is
            // what happens to be on it, which is the opposite of an album and a track.
            Text(channel.qualifiedName)
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let programme = serviceManager.getCurrentProgram(for: channel)?.programmeName,
               !programme.isEmpty {
                Text(programme)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
                    .padding(.top, 10)
            }

            if let track = serviceManager.currentTrack {
                Text(track.displayText)
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .padding(.top, 12)
            }

            Spacer(minLength: 36)

            programmeProgress(for: channel)

            tvOSNowPlayingControls(
                serviceManager: serviceManager,
                showingInfoSheet: $showingInfoSheet,
                showingScheduleSheet: $showingScheduleSheet,
                channel: channel
            )
            .padding(.top, 34)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
    }

    /// How far through the programme the broadcast is, with the hour it started and the hour
    /// it ends.
    ///
    /// Live radio has nothing to scrub, so this is a read-out rather than a control — which
    /// is also why it is not focusable and does not wake the controls.
    ///
    /// Driven by a `TimelineView` rather than a timer of its own: the bar only has to be
    /// right to the nearest minute on a screen someone is looking at, and a view that
    /// redraws itself needs no state to keep in sync.
    @ViewBuilder
    private func programmeProgress(for channel: DRChannel) -> some View {
        if let programme = serviceManager.getCurrentProgram(for: channel),
           let start = programme.startDate,
           let end = programme.endDate {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                VStack(alignment: .leading, spacing: 12) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.22))
                            Capsule()
                                .fill(.white)
                                .frame(width: proxy.size.width
                                       * (programme.progress(at: context.date) ?? 0))
                        }
                    }
                    .frame(height: 8)

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

}

// MARK: - Blurred Background
struct tvOSNowPlayingBackground: View {
    let channel: DRChannel
    @ObservedObject var serviceManager: DRServiceManager

    private var artworkURL: URL? {
        guard let program = serviceManager.getCurrentProgram(for: channel),
              let urlString = program.landscapeImageURL ?? program.primaryImageURL
        else { return nil }
        return URL(string: urlString)
    }

    var body: some View {
        ZStack {
            Color.black

            if let url = artworkURL {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(1.15)
                        .blur(radius: 70)
                        .opacity(0.55)
                } placeholder: {
                    Color.black
                }
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.2),
                    Color.black.opacity(0.45),
                    Color.black.opacity(0.75)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Artwork Card
struct tvOSNowPlayingArtworkCard: View {
    let channel: DRChannel
    @ObservedObject var serviceManager: DRServiceManager
    @State private var pillBackground: Color = Color.white.opacity(0.15)
    @State private var pillForeground: Color = .white

    private var artworkURL: URL? {
        guard let program = serviceManager.getCurrentProgram(for: channel),
              let urlString = program.primaryImageURL ?? program.landscapeImageURL
        else { return nil }
        return URL(string: urlString)
    }

    var body: some View {
        CachedAsyncImage(url: artworkURL) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                Color.white.opacity(0.08)
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 72))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .frame(width: 400, height: 400)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 13, weight: .bold))
                Text(channel.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(pillForeground)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            // 12, not 10: the badge is inset 12 from a card with a 24 radius, and a nested
            // shape that meets a corner takes the outer radius minus that inset. At 10 the
            // gap between the two curves narrowed as it went round the corner.
            .background(pillBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(12)
            .animation(.easeInOut(duration: 0.4), value: pillBackground)
        }
        .shadow(color: .black.opacity(0.6), radius: 40, x: 0, y: 20)
        .task(id: artworkURL) { await updatePillColors() }
    }

    private func updatePillColors() async {
        // Reuse the image the card above is already showing. This used to fetch the same
        // artwork a second time over the network, purely to read a few pixels from it.
        guard let url = artworkURL,
              let uiImage = await ImageCacheService.shared.image(for: url.absoluteString),
              let cgImage = uiImage.cgImage else { return }

        // Sample the top-right region where the pill sits
        let w = cgImage.width, h = cgImage.height
        let sampleRect = CGRect(x: Int(Double(w) * 0.55), y: 0,
                                width: Int(Double(w) * 0.45), height: Int(Double(h) * 0.35))
        guard let cropped = cgImage.cropping(to: sampleRect) else { return }

        // Average color via CIAreaAverage
        let ciImage = CIImage(cgImage: cropped)
        let extent = ciImage.extent
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(x: extent.origin.x, y: extent.origin.y,
                                        z: extent.size.width, w: extent.size.height)
        ]), let output = filter.outputImage else { return }

        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext().render(output, toBitmap: &bitmap, rowBytes: 4,
                           bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                           format: .RGBA8, colorSpace: nil)

        let r = CGFloat(bitmap[0]) / 255
        let g = CGFloat(bitmap[1]) / 255
        let b = CGFloat(bitmap[2]) / 255

        // Shift hue 180° for the complementary colour
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        UIColor(red: r, green: g, blue: b, alpha: 1)
            .getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
        let compHue = (hue + 0.5).truncatingRemainder(dividingBy: 1.0)
        let compColor = UIColor(hue: compHue,
                                saturation: min(sat + 0.15, 1.0),
                                brightness: max(bri, 0.45),
                                alpha: 0.88)

        // Pick foreground that contrasts with the complementary background
        var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0
        compColor.getRed(&cr, green: &cg, blue: &cb, alpha: nil)
        let lum = 0.2126 * cr + 0.7152 * cg + 0.0722 * cb
        let fg: Color = lum > 0.45 ? .black : .white

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.4)) {
                pillBackground = Color(compColor)
                pillForeground = fg
            }
        }
    }
}


// MARK: - Controls Row (Info | Play/Pause | SharePlay)
struct tvOSNowPlayingControls: View {
    @ObservedObject var serviceManager: DRServiceManager
    @Binding var showingInfoSheet: Bool
    @Binding var showingScheduleSheet: Bool
    let channel: DRChannel
    @FocusState private var focused: ControlButton?

    enum ControlButton: Hashable { case info, play, shareplay, schedule }

    var body: some View {
        HStack(spacing: 32) {
            Button {
                showingInfoSheet = true
            } label: {
                IconCircleLabel(systemImage: "info.circle", size: 64, iconSize: 28)
            }
            .buttonStyle(tvOSMusicCardButtonStyle())
            .focused($focused, equals: .info)

            // Play / Pause (centre, larger)
            Button {
                serviceManager.togglePlayback(for: channel)
            } label: {
                PlayPauseLabel(isPlaying: serviceManager.isPlaying)
            }
            .buttonStyle(tvOSMusicCardButtonStyle())
            .focused($focused, equals: .play)

            Button {
                if let ch = serviceManager.playingChannel { startSharePlay(for: ch) }
            } label: {
                IconCircleLabel(systemImage: "shareplay", size: 64, iconSize: 28)
            }
            .buttonStyle(tvOSMusicCardButtonStyle())
            .focused($focused, equals: .shareplay)

            // What else is on. iOS has had this from the full player since the list button
            // was wired up; the television could not ask at all.
            Button {
                showingScheduleSheet = true
            } label: {
                IconCircleLabel(systemImage: "list.bullet", size: 64, iconSize: 28)
            }
            .buttonStyle(tvOSMusicCardButtonStyle())
            .focused($focused, equals: .schedule)
            .accessibilityLabel("Schedule")
        }
    }

    // Inner view: small icon buttons (info, shareplay)
    private struct IconCircleLabel: View {
        let systemImage: String
        let size: CGFloat
        let iconSize: CGFloat
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(isFocused ? Color.black : Color.white)
                .frame(width: size, height: size)
                .background(isFocused ? Color.white : Color.clear, in: Circle())
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .gray.opacity(isFocused ? 0.25 : 0), radius: 12, x: 0, y: 0)
                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isFocused)
        }
    }

    // Inner view: play/pause button
    private struct PlayPauseLabel: View {
        let isPlaying: Bool
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            ZStack {
                Circle()
                    .fill(isFocused ? Color.white : Color.white.opacity(0.15))
                    .frame(width: 88, height: 88)
                if !isFocused {
                    Circle()
                        .stroke(.white.opacity(0.25), lineWidth: 2)
                        .frame(width: 88, height: 88)
                }
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(isFocused ? Color.black : Color.white)
                    .offset(x: isPlaying ? 0 : 3)
            }
            .shadow(color: .white.opacity(isFocused ? 0.55 : 0), radius: 18, x: 0, y: 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isFocused)
        }
    }

    private func startSharePlay(for channel: DRChannel) {
        #if canImport(GroupActivities)
        if #available(tvOS 15.0, *) {
            let activity = RadioShareActivity(channelId: channel.id, channelTitle: channel.title)
            Task {
                do {
                    _ = try await activity.activate()
                } catch {
                    Log.playback.error(
                        "SharePlay activation failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        #endif
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
                    ZStack {
                        Color.white.opacity(0.07)
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 44))
                            .foregroundStyle(.white.opacity(0.25))
                    }
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

            // Right: Info
            ScrollView(.vertical, showsIndicators: false) {
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
                        Text(desc)
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.leading)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 24)
                    }

                    Spacer(minLength: 44)
                }
                .padding(.top, 44)
                .padding(.leading, 32)
                .padding(.trailing, 44)
                .padding(.bottom, 44)
            }
        }
        .frame(maxWidth: 1260)
        .frame(minHeight: 340 + 88)
        .background(.clear)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .shadow(color: .black.opacity(0.6), radius: 80, x: 0, y: 40)
        .padding(60)
    }
}
#endif

#if canImport(GroupActivities)
/// The SharePlay activity for listening together.
///
/// Declared here rather than inside `startSharePlay`, and `nonisolated`: nested in a
/// main-actor method its `GroupActivity` conformance was main-actor isolated, and
/// `activate()` is awaited from a concurrent task. Swift 6 rejects that — an isolated
/// conformance cannot cross into a concurrent context.
@available(tvOS 15.0, *)
nonisolated struct RadioShareActivity: GroupActivity {
    static let activityIdentifier = "com.eopio.lytter.shareplay.radio"

    let channelId: String
    let channelTitle: String

    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = channelTitle
        metadata.type = .watchTogether
        return metadata
    }
}
#endif
