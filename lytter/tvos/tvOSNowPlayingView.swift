//
//  tvOSNowPlayingView.swift
//  lytter
//

import SwiftUI
import UIKit
import CoreImage
#if canImport(GroupActivities)
import GroupActivities
#endif

#if os(tvOS)

// MARK: - Remote Interaction Detector
/// Attaches a pass-through gesture recognizer to the UIWindow so it sees
/// ALL remote input — touchpad swipes, directional presses, and select —
/// before the focus engine routes events to individual views.
/// Setting state = .failed immediately means events are never consumed.
private class PassThroughGestureRecognizer: UIGestureRecognizer {
    var onInteraction: (() -> Void)?

    // Touchpad begin (swipe start, tap start)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        onInteraction?()
        state = .failed
    }

    // All physical button presses (select, menu, play/pause, d-pad directions)
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent) {
        onInteraction?()
        state = .failed
    }
}

/// A transparent view that, as soon as it enters the window hierarchy,
/// installs the pass-through recognizer onto the UIWindow itself.
private class RemoteDetectorHostView: UIView {
    var onInteraction: (() -> Void)?
    private weak var installedRecognizer: PassThroughGestureRecognizer?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Remove any previously installed recognizer
        if let old = installedRecognizer {
            old.view?.removeGestureRecognizer(old)
            installedRecognizer = nil
        }
        // Install onto the window so it fires ahead of the focus engine
        if let win = window {
            let recognizer = PassThroughGestureRecognizer()
            recognizer.onInteraction = { [weak self] in self?.onInteraction?() }
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            win.addGestureRecognizer(recognizer)
            installedRecognizer = recognizer
        }
    }

    deinit {
        if let old = installedRecognizer {
            old.view?.removeGestureRecognizer(old)
        }
    }
}

private struct RemoteInteractionDetector: UIViewRepresentable {
    let onInteraction: () -> Void

    func makeUIView(context: Context) -> RemoteDetectorHostView {
        let view = RemoteDetectorHostView()
        view.backgroundColor = .clear
        view.onInteraction = onInteraction
        return view
    }

    func updateUIView(_ uiView: RemoteDetectorHostView, context: Context) {
        uiView.onInteraction = onInteraction
    }
}

// MARK: - Tab Bar Visibility Helper
/// Hides/shows the tab bar by toggling both alpha (for a smooth fade) and
/// isUserInteractionEnabled.  Setting isUserInteractionEnabled = false removes
/// the bar from the tvOS focus system entirely, preventing the focus engine
/// from cycling to invisible tab-bar items and causing a show/hide flicker.
private func setTabBarVisible(_ visible: Bool) {
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = scene.windows.first else { return }
    func findTabBar(in vc: UIViewController?) -> UITabBarController? {
        if let tbc = vc as? UITabBarController { return tbc }
        return vc?.children.compactMap { findTabBar(in: $0) }.first
    }
    guard let tbc = findTabBar(in: window.rootViewController) else { return }
    if visible {
        // Re-enable interaction before the fade-in so focus can return to it.
        tbc.tabBar.isUserInteractionEnabled = true
    }
    UIView.animate(withDuration: 0.4) {
        tbc.tabBar.alpha = visible ? 1 : 0
    } completion: { finished in
        // A fade-out interrupted by a later setTabBarVisible(true) still runs this
        // block, with finished == false. Disabling interaction then would leave a
        // fully opaque tab bar that the focus engine ignores, which is the exact
        // flicker this helper exists to prevent — so only act on a fade that ran
        // to completion.
        guard finished, !visible else { return }
        // Disable after fade-out so the focus engine ignores it completely.
        tbc.tabBar.isUserInteractionEnabled = false
    }
}

// MARK: - Now Playing
struct tvOSNowPlayingView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @State private var showingInfoSheet = false
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if let channel = serviceManager.playingChannel {
                // Full-screen blurred artwork background
                tvOSNowPlayingBackground(channel: channel, serviceManager: serviceManager)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Artwork — centred, large
                    tvOSNowPlayingArtworkCard(channel: channel, serviceManager: serviceManager)

                    Spacer().frame(height: 36)

                    // Program title
                    if let title = serviceManager.getCurrentProgram(for: channel)?.cleanTitle(),
                       !title.isEmpty {
                        Text(title)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 3)
                    }

                    // Currently playing track
                    if let track = serviceManager.currentTrack {
                        Text(track.displayText)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .padding(.top, 6)
                    }

                    Spacer().frame(height: 44)

                    // Controls row: Info | Play/Pause | SharePlay
                    HStack(spacing: 40) {
                        tvOSNowPlayingControls(
                            serviceManager: serviceManager,
                            showingInfoSheet: $showingInfoSheet,
                            channel: channel,
                            onInteraction: wakeControls
                        )
                    }
                    .padding(.bottom, 60)
                    .opacity(controlsVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.4), value: controlsVisible)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                // UIKit-level pass-through: fires on any remote press/swipe
                // without consuming the event, so buttons and focus still work.
                .background(RemoteInteractionDetector(onInteraction: wakeControls))
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
        .onAppear { startHideTimer() }
        .onDisappear {
            hideTask?.cancel()
            setTabBarVisible(true) // always restore when leaving
        }
    }

    private func wakeControls() {
        startHideTimer()
    }

    private func startHideTimer() {
        hideTask?.cancel()
        withAnimation(.easeInOut(duration: 0.3)) { controlsVisible = true }
        setTabBarVisible(true)
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) { controlsVisible = false }
                setTabBarVisible(false)
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
        AsyncImage(url: artworkURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                ZStack {
                    Color.white.opacity(0.08)
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 72))
                        .foregroundStyle(.white.opacity(0.3))
                }
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
            .background(pillBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(12)
            .animation(.easeInOut(duration: 0.4), value: pillBackground)
        }
        .shadow(color: .black.opacity(0.6), radius: 40, x: 0, y: 20)
        .task(id: artworkURL) { await updatePillColors() }
    }

    private func updatePillColors() async {
        guard let url = artworkURL,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let uiImage = UIImage(data: data),
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
    let channel: DRChannel
    var onInteraction: (() -> Void)? = nil
    @FocusState private var focused: ControlButton?

    enum ControlButton: Hashable { case info, play, shareplay }

    var body: some View {
        HStack(spacing: 32) {
            Button {
                onInteraction?()
                showingInfoSheet = true
            } label: {
                IconCircleLabel(systemImage: "info.circle", size: 64, iconSize: 28)
            }
            .buttonStyle(tvOSMusicCardButtonStyle())
            .focused($focused, equals: .info)

            // Play / Pause (centre, larger)
            Button {
                onInteraction?()
                serviceManager.togglePlayback(for: channel)
            } label: {
                PlayPauseLabel(isPlaying: serviceManager.isPlaying)
            }
            .buttonStyle(tvOSMusicCardButtonStyle())
            .focused($focused, equals: .play)

            Button {
                onInteraction?()
                if let ch = serviceManager.playingChannel { startSharePlay(for: ch) }
            } label: {
                IconCircleLabel(systemImage: "shareplay", size: 64, iconSize: 28)
            }
            .buttonStyle(tvOSMusicCardButtonStyle())
            .focused($focused, equals: .shareplay)
        }
        // Wake controls on focus change within the row
        .onChange(of: focused) { onInteraction?() }
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
            struct RadioShareActivity: GroupActivity {
                static let activityIdentifier = "com.eopio.lytter.shareplay.radio"
                let channelId: String; let channelTitle: String
                var metadata: GroupActivityMetadata {
                    var d = GroupActivityMetadata(); d.title = channelTitle; d.type = .watchTogether; return d
                }
            }
            Task { do { _ = try await RadioShareActivity(channelId: channel.id, channelTitle: channel.title).activate() } catch {} }
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
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        ZStack {
                            Color.white.opacity(0.07)
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 44))
                                .foregroundStyle(.white.opacity(0.25))
                        }
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
