    //
    //  AudioPlayerService.swift
    //  ios
    //
    //  Created by Emmanuel on 27/07/2025.
    //

import Foundation
import AVFoundation
import Combine
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import MediaPlayer
import AVKit
import os

    // MARK: - iOS Audio Player Service

class AudioPlayerService: NSObject, ObservableObject {
    private var player: AVPlayer?
    /// Subscriptions belonging to the *current* AVPlayer and AVPlayerItem.
    ///
    /// These must be torn down whenever the player is replaced or stopped. They capture
    /// the item and subscribe to the player, so leaving them in place retains both, and
    /// a discarded player still writing `isPlaying` would fight the live one.
    private var playerObservations = Set<AnyCancellable>()
    /// Keeps canSeek/isBehindLive current. Belongs to one AVPlayer, so it is removed
    /// before that player is replaced.
    private var timeObserver: (player: AVPlayer, token: Any)?
    
    @Published var isPlaying = false
    @Published var duration: TimeInterval = 0
    @Published var isLoading = false
    /// True when the stream carries a DVR window to seek within. DR's HLS streams do
    /// (about 34 minutes, sliding); the ICY fallback has none.
    @Published private(set) var canSeek = false
    /// True when playback sits far enough back from the live edge to offer "Live".
    @Published private(set) var isBehindLive = false
    /// How far behind live, in whole seconds, while `isBehindLive`; otherwise 0. Whole
    /// seconds so it publishes at most once a second, and only when it moves.
    @Published private(set) var secondsBehindLive: TimeInterval = 0
    @Published var error: String?

    /// Whether the listener means audio to be coming out: set by starting or resuming,
    /// cleared by pausing or stopping. Not `isPlaying`, which follows the player and goes
    /// false when a stream fails or stalls on a dead connection — exactly the case where
    /// the app has to know the listener still wants it back (F42).
    private(set) var wantsPlayback = false
    
        // Control for screen sleep behavior
    @Published var preventScreenSleep = false
    
        // AirPlay properties
    // AVAudioSession has no macOS counterpart at all -- audio routing there is a
    // different system entirely (Core Audio device selection), not a per-app session with
    // interruptions and routes. Guarded rather than shimmed: there is no macOS screen yet
    // to show an AirPlay indicator on, so there is nothing this needs to stand in for.
    #if os(iOS) || os(tvOS)
    @Published var isAirPlayActive = false
    @Published var currentAirPlayRoute: AVAudioSessionRouteDescription?
    #endif
    
        // Command Center properties
    private var commandCenter: MPRemoteCommandCenter?
    private var nowPlayingInfoCenter: MPNowPlayingInfoCenter?
    #if os(tvOS)
    // Bound only on tvOS 14+ to satisfy PineBoard playback queue callbacks
    private var tvOSNowPlayingSession: MPNowPlayingSession?
    #endif
    
    override init() {
        super.init()
        setupCommandCenter()
        #if os(iOS) || os(tvOS)
        setupAudioInterruptionHandling()
        #endif
            // Allow screen sleep by default on app launch
        setPreventScreenSleep(false)
            // Audio session will be setup when first needed
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)

        // The Command Center is deliberately not cleaned up here. Its targets capture self
        // weakly, so they are inert once this object is gone, and `stop()` already clears
        // the now-playing info. Reaching for it from deinit means touching main-actor
        // state from a nonisolated context — a warning today and an error under Swift 6,
        // for a cleanup that cannot run anyway: the one instance is owned by the app-wide
        // DRServiceManager and outlives everything that could observe it.
    }
    
    private var audioSessionSetup = false
    private var interruption = InterruptionState()
    
    // MARK: - Audio Interruption Handling

    #if os(iOS) || os(tvOS)
    private func setupAudioInterruptionHandling() {
        // Observe audio session interruptions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        // Observe when audio session becomes active/inactive
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleAudioInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Audio interruption started (e.g., phone call, alarm, etc.)
            interruption.began(wasPlaying: isPlaying)
            if isPlaying {
                // resumable: this pause is the system's doing, so it must not clear the
                // intent that was just recorded.
                pause(resumable: true)
            }
            
        case .ended:
            // Audio interruption ended
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            // ended() clears the intent whether or not it resumes. Previously an
            // interruption that ended without .shouldResume left the flag set, and the
            // next route change found it and started playing.
            if interruption.ended(systemAllowsResume: options.contains(.shouldResume)) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.resumeAfterInterruption()
                }
            }
            
        @unknown default:
            break
        }
    }
    
    @objc private func handleAudioSessionRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // The output device went away — headphones unplugged, Bluetooth disconnected.
            // Pausing is required behaviour; audio must not carry on out of the speaker.
            // The default pause() clears any resume intent, because Apple's guidance is
            // not to restart when the route comes back.
            if isPlaying {
                pause()
            }

            // .newDeviceAvailable is deliberately not handled. Plugging something in means
            // a route became available, not that the listener wants audio — and resuming
            // here is what turned a stale interruption flag into the radio starting by
            // itself an hour after the call that set it.

        default:
            break
        }
    }
    
    private func resumeAfterInterruption() {
        // The decision was made by InterruptionState.ended(); this only carries it out.
        guard player != nil else { return }

        activateSession(longFormAudio: true, context: "after an interruption") { [weak self] activated in
            guard activated, let self, let player = self.player else { return }
            player.play()
            self.isPlaying = true
            self.updateCommandCenterPlaybackState()
        }
    }
    #endif

        // MARK: - Screen Sleep Control
    
    private func updateIdleTimer() {
        #if os(iOS) || os(tvOS)
        UIApplication.shared.isIdleTimerDisabled = preventScreenSleep
        #endif
        // No macOS branch: preventing App Nap / display sleep there is a different
        // mechanism (an IOPMAssertion), not an idle-timer flag, and this app has no
        // macOS screen to keep awake yet.
    }
    
        // MARK: - AirPlay Support

    #if os(iOS) || os(tvOS)
    private func setupAirPlayMonitoring() {
            // Monitor route changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
            // Initial route check
        updateAirPlayStatus()
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.updateAirPlayStatus()
        }
    }
    
    
    
    private func updateAirPlayStatus() {
        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute
        
            // Check if AirPlay is active
        let isAirPlay = currentRoute.outputs.contains { output in
            output.portType == .airPlay
        }
        
            // Check if external audio is active (AirPlay, Bluetooth, etc.)
        let externalPortTypes: [AVAudioSession.Port] = [.airPlay, .bluetoothA2DP, .bluetoothLE, .bluetoothHFP]
        let isExternalAudio = currentRoute.outputs.contains { output in
            externalPortTypes.contains(output.portType)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.isAirPlayActive = isAirPlay
            self?.currentAirPlayRoute = isExternalAudio ? currentRoute : nil
        }
    }
    #endif



        // MARK: - Command Center Setup
    
    private func setupCommandCenter() {
        // Start with the shared center; on tvOS we rebind to MPNowPlayingSession when the player is created
        commandCenter = MPRemoteCommandCenter.shared()
        nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        configureRemoteCommandTargets()
    }

    private func configureRemoteCommandTargets() {
        // Ensure we are starting clean for the current command center
        commandCenter?.playCommand.removeTarget(nil)
        commandCenter?.pauseCommand.removeTarget(nil)
        commandCenter?.stopCommand.removeTarget(nil)
        commandCenter?.togglePlayPauseCommand.removeTarget(nil)
        commandCenter?.skipForwardCommand.removeTarget(nil)
        commandCenter?.skipBackwardCommand.removeTarget(nil)
        commandCenter?.seekForwardCommand.removeTarget(nil)
        commandCenter?.seekBackwardCommand.removeTarget(nil)
        commandCenter?.changePlaybackPositionCommand.removeTarget(nil)

        // Enable explicitly. A command center taken from an MPNowPlayingSession on tvOS
        // does not necessarily start with these enabled, and a disabled command is never
        // delivered to its handler — pause could work while play never arrived.
        commandCenter?.playCommand.isEnabled = true
        commandCenter?.pauseCommand.isEnabled = true
        commandCenter?.stopCommand.isEnabled = true
        commandCenter?.togglePlayPauseCommand.isEnabled = true

        // Configure play command
        commandCenter?.playCommand.addTarget { [weak self] _ in
            Log.playback.info("remote play command")
            guard let self else { return .commandFailed }
            if self.hasLoadedItem {
                self.resume()
                return .success
            }
            // Nothing is loaded and nobody is listening for a request to start a
            // stream, so playback cannot begin. Reporting .success here would make
            // the system show a pause button for audio that never started.
            guard let onRequestPlay = self.onRequestPlay else {
                return .noActionableNowPlayingItem
            }
            onRequestPlay()
            return .success
        }

        // Configure pause command
        commandCenter?.pauseCommand.addTarget { [weak self] _ in
            Log.playback.info("remote pause command")
            self?.pause()
            return .success
        }

        // Configure stop command (acts like pause for live radio)
        commandCenter?.stopCommand.addTarget { [weak self] _ in
            Log.playback.info("remote stop command")
            self?.pause()
            return .success
        }

        // Configure toggle play/pause command
        commandCenter?.togglePlayPauseCommand.addTarget { [weak self] _ in
            Log.playback.info("remote togglePlayPause command")
            guard let self else { return .commandFailed }
            if self.isPlaying {
                self.pause()
                return .success
            }
            if self.hasLoadedItem {
                self.resume()
                return .success
            }
            guard let onRequestPlay = self.onRequestPlay else {
                return .noActionableNowPlayingItem
            }
            onRequestPlay()
            return .success
        }

        // Skip works within the HLS stream's DVR window. It is enabled only while there
        // is one (updateSkipCommandsEnabled): the ICY fallback has no seekable range, and
        // advertising skip there put buttons on the lock screen that did nothing.
        let interval = NSNumber(value: Self.skipInterval)
        commandCenter?.skipBackwardCommand.preferredIntervals = [interval]
        commandCenter?.skipForwardCommand.preferredIntervals = [interval]
        commandCenter?.skipBackwardCommand.addTarget { [weak self] event in
            guard let self, self.canSeek else { return .commandFailed }
            let seconds = (event as? MPSkipIntervalCommandEvent)?.interval ?? Self.skipInterval
            self.skip(by: -seconds)
            return .success
        }
        commandCenter?.skipForwardCommand.addTarget { [weak self] event in
            guard let self, self.canSeek else { return .commandFailed }
            let seconds = (event as? MPSkipIntervalCommandEvent)?.interval ?? Self.skipInterval
            self.skip(by: seconds)
            return .success
        }
        updateSkipCommandsEnabled()

        // Continuous seek and scrubbing to a position stay off: the lock screen has no
        // meaningful position on a live stream to scrub along.
        commandCenter?.seekForwardCommand.isEnabled = false
        commandCenter?.seekBackwardCommand.isEnabled = false
        commandCenter?.changePlaybackPositionCommand.isEnabled = false
    }
    
    private func cleanupCommandCenter() {
            // Remove all command targets
        commandCenter?.playCommand.removeTarget(nil)
        commandCenter?.pauseCommand.removeTarget(nil)
        commandCenter?.stopCommand.removeTarget(nil)
        commandCenter?.togglePlayPauseCommand.removeTarget(nil)
        commandCenter?.skipForwardCommand.removeTarget(nil)
        commandCenter?.skipBackwardCommand.removeTarget(nil)
        commandCenter?.seekForwardCommand.removeTarget(nil)
        commandCenter?.seekBackwardCommand.removeTarget(nil)
        
            // Clear now playing info
        nowPlayingInfoCenter?.nowPlayingInfo = nil
    }

    #if os(tvOS)
    private func rebindCommandCenterToNowPlayingSessionIfNeeded(for player: AVPlayer) {
        if #available(tvOS 14.0, *) {
            // Create or update the tvOS Now Playing session so PineBoard can request the playback queue and artwork formats
            let session = MPNowPlayingSession(players: [player])
            tvOSNowPlayingSession = session

            // Make the session active
            session.becomeActiveIfPossible { _ in }

            // Rebind centers to the session and configure commands
            cleanupCommandCenter()
            self.commandCenter = session.remoteCommandCenter
            self.nowPlayingInfoCenter = session.nowPlayingInfoCenter
            self.configureRemoteCommandTargets()
        }
    }
    #endif
    
        // MARK: - Command Center Info Updates
    
    /// Wraps an image as lock-screen artwork.
    ///
    /// `nonisolated` deliberately. MediaPlayer calls the request handler on its own queue,
    /// and under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` a closure written inline in a
    /// main-actor method is main-actor isolated. Swift 6 enforces that with a runtime
    /// check, so the handler trapped — `dispatch_assert_queue` → SIGTRAP — the moment the
    /// lock screen asked for artwork. The image is captured and returned unchanged, so
    /// there is nothing here that needs isolating.
    private nonisolated static func artwork(for image: PlatformImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    func updateCommandCenterInfo(channel: DRChannel, program: DREpisode?, track: DRTrack? = nil) {
        var nowPlayingInfo: [String: Any] = [:]
        
            // Determine what to show as title and artist based on available information
        if let track = track, track.isPlaying(at: Date().addingTimeInterval(-secondsBehindLive)) {
                // Show track info when track is currently playing
            nowPlayingInfo[MPMediaItemPropertyTitle] = "\(channel.title) - \(program?.cleanTitle() ?? "")"
            nowPlayingInfo[MPMediaItemPropertyArtist] = track.displayText
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = program?.cleanTitle() ?? "DR Radio"
        } else if let program = program {
                // Show program info when no track is playing
            nowPlayingInfo[MPMediaItemPropertyTitle] = channel.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = program.cleanTitle()
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "DR Radio"
        } else {
                // Fallback to channel info
            nowPlayingInfo[MPMediaItemPropertyTitle] = channel.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = "DR Radio"
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "Live"
        }
        
            // Set duration and elapsed time to show "LIVE" in progress bar
            // Using a small duration to show progress bar with "LIVE" text
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = 1.0
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.5
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        
            // Add live indicator
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        
            // Set playback rate
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
            // Set default artwork if no program image
        if let program = program, let imageURLString = program.primaryImageURL, let imageURL = URL(string: imageURLString) {
                // Load image asynchronously
            loadImageForCommandCenter(from: imageURL) { [weak self] image in
                if let image = image {
                    nowPlayingInfo[MPMediaItemPropertyArtwork] = Self.artwork(for: image)
                    self?.nowPlayingInfoCenter?.nowPlayingInfo = nowPlayingInfo
                } else {
                        // Fallback to default artwork
                    self?.setDefaultCommandCenterArtwork(nowPlayingInfo: nowPlayingInfo)
                }
            }
        } else {
                // Use default artwork
            setDefaultCommandCenterArtwork(nowPlayingInfo: nowPlayingInfo)
        }
        
            // Update the now playing info
        nowPlayingInfoCenter?.nowPlayingInfo = nowPlayingInfo
    }
    
    private func loadImageForCommandCenter(from url: URL, completion: @escaping (PlatformImage?) -> Void) {
        // Through the cache: this runs on every now-playing metadata update — each track
        // change, each programme change — and it is almost always the same artwork the
        // player screen is already showing.
        ImageCacheService.shared.loadImage(from: url.absoluteString, completion: completion)
    }
    
    private func setDefaultCommandCenterArtwork(nowPlayingInfo: [String: Any]) {
        var updatedInfo = nowPlayingInfo
        updatedInfo[MPMediaItemPropertyArtwork] = Self.artwork(for: defaultArtworkImage())
        nowPlayingInfoCenter?.nowPlayingInfo = updatedInfo
    }

    #if os(iOS) || os(tvOS)
    /// A gradient with the radio glyph over it, drawn once as a fallback for artwork DR
    /// did not send.
    private func defaultArtworkImage() -> PlatformImage {
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor] as CFArray,
                                      locations: [0.0, 1.0])!

            context.cgContext.drawLinearGradient(gradient,
                                                 start: CGPoint(x: 0, y: 0),
                                                 end: CGPoint(x: size.width, y: size.height),
                                                 options: [])

            let iconSize: CGFloat = 120
            let iconRect = CGRect(x: (size.width - iconSize) / 2,
                                  y: (size.height - iconSize) / 2,
                                  width: iconSize,
                                  height: iconSize)

            let iconConfig = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .medium)
            let radioIcon = UIImage(systemName: "antenna.radiowaves.left.and.right", withConfiguration: iconConfig)
            radioIcon?.withTintColor(.white, renderingMode: .alwaysOriginal)
                .draw(in: iconRect)
        }
    }
    #elseif os(macOS)
    /// A plain gradient square, drawn now, into a bitmap.
    ///
    /// Not `NSImage(size:flipped:drawingHandler:)`. That draws later, whenever the image is
    /// rendered — and MediaPlayer renders now-playing artwork on its own queue. The handler,
    /// main-actor isolated by the project's default, then failed Swift's isolation check
    /// there and the app trapped as it opened, before a window appeared. iOS's renderer
    /// draws eagerly, which is why it never did.
    static func defaultArtworkImage() -> PlatformImage {
        let pixels = 300
        let size = NSSize(width: pixels, height: pixels)
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels,
                                            pixelsHigh: pixels, bitsPerSample: 8,
                                            samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                            colorSpaceName: .deviceRGB, bytesPerRow: 0,
                                            bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return NSImage(size: size)
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSGradient(starting: .systemBlue, ending: .systemPurple)?
            .draw(in: NSRect(origin: .zero, size: size), angle: -45)
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        return image
    }

    private func defaultArtworkImage() -> PlatformImage { Self.defaultArtworkImage() }
    #endif
    
    private func updateSkipCommandsEnabled() {
        commandCenter?.skipBackwardCommand.isEnabled = canSeek
        commandCenter?.skipForwardCommand.isEnabled = canSeek
    }

    func updateCommandCenterPlaybackState() {
        var nowPlayingInfo = nowPlayingInfoCenter?.nowPlayingInfo ?? [:]
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        nowPlayingInfoCenter?.nowPlayingInfo = nowPlayingInfo
        
            // Skip and seek stay disabled: there is nothing to seek within on a live
            // stream. See configureRemoteCommandTargets.
    }
    
    func clearCommandCenterInfo() {
        nowPlayingInfoCenter?.nowPlayingInfo = nil
    }
    
        // Convenience method to update command center with current track info
    func updateCommandCenterWithTrack(channel: DRChannel, program: DREpisode?, track: DRTrack?) {
        updateCommandCenterInfo(channel: channel, program: program, track: track)
    }
    
    
    
    func play(url: URL) {
        pausedAt = nil
        isLoading = true
        error = nil
        wantsPlayback = true
        // Starting a channel is deliberate, so any pending resume intent is void.
        interruption.playbackSettledDeliberately()
        
            // Activate the session off the main thread; the player is built meanwhile.
            // There is no need to wait: the item has to load over the network before
            // readyToPlay calls play(), and the session queue is done long before that.
        activateSession(context: "play")
        #if os(iOS) || os(tvOS)
        if !audioSessionSetup {
            setupAirPlayMonitoring()
            audioSessionSetup = true
        }
        #endif
        
            // Create new player item
        let playerItem = AVPlayerItem(url: url)

            // Tear down everything tied to the outgoing player before replacing it.
            // The two sinks below capture their AVPlayerItem and subscribe to their
            // AVPlayer, so leaving them subscribed kept one of each alive per channel
            // switch — and each one carried on writing isPlaying/isLoading on this
            // service. A discarded player reaching .paused would then flip the UI to
            // "paused" while the channel the user just chose was playing.
        playerObservations.removeAll()
        removeTimeObserver()

        // Create new player
        player = AVPlayer(playerItem: playerItem)
        addTimeObserver()

        #if os(tvOS)
        if let player = player {
            rebindCommandCenterToNowPlayingSessionIfNeeded(for: player)
        }
        #endif
        
            // The one periodic observer (addTimeObserver, above) only tracks where playback
            // sits in the DVR window. There is still no `currentTime` to publish: the two
            // players that show a progress bar drive it from their own @State.
        
            // Observe player item status
        playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                    case .readyToPlay:
                        self?.isLoading = false
                        self?.duration = playerItem.duration.seconds
                        self?.player?.play()
                        self?.isPlaying = true
                            // Update Command Center playback state
                        self?.updateCommandCenterPlaybackState()
                    case .failed:
                        Log.playback.error(
                            "stream failed: \(playerItem.error?.localizedDescription ?? "no error", privacy: .public)")
                        self?.isLoading = false
                        self?.error = playerItem.error?.localizedDescription ?? "Failed to load audio"
                    case .unknown:
                        break
                    @unknown default:
                        break
                }
            }
            .store(in: &playerObservations)
        
            // Observe playback status
        player?.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                    case .playing:
                        self?.isPlaying = true
                            // Update Command Center playback state
                        self?.updateCommandCenterPlaybackState()
                    case .paused:
                        self?.isPlaying = false
                            // Update Command Center playback state
                        self?.updateCommandCenterPlaybackState()
                    case .waitingToPlayAtSpecifiedRate:
                        self?.isLoading = true
                    @unknown default:
                        break
                }
            }
            .store(in: &playerObservations)
    }
    
    /// Pauses playback.
    ///
    /// - Parameter resumable: whether a later interruption-ended event may resume. Only
    ///   the interruption handler passes `true`; every other caller — the listener, the
    ///   Command Center, an unplugged output device — means the pause to stand, and
    ///   clearing the intent here is what stops a stale one firing later.
    ///
    ///   The condition this replaces read `if !wasPlayingBeforeInterruption { ... = false }`,
    ///   which assigns false only when it is already false. It never cleared anything.
    func pause(resumable: Bool = false) {
        player?.pause()
        isPlaying = false
        wantsPlayback = false
        pausedAt = Date()

        if !resumable {
            interruption.playbackSettledDeliberately()
        }

            // The session deliberately stays active. Pausing live radio is momentary, and
            // deactivating here tore the session down and rebuilt it on every resume —
            // an audible delay, and it handed audio focus to whatever else was running,
            // which could duck or stop us. stop() is where the session is released.

        // Update Command Center playback state
        updateCommandCenterPlaybackState()
    }
    
    /// True when a *usable* AVPlayerItem is loaded (i.e. play(url:) has been called this
    /// session and the item has not failed).
    ///
    /// A failed item stays attached to the player, so checking only for a non-nil
    /// currentItem would report true for a dead stream. Callers would then resume() a
    /// player that can never produce audio, and because the channel still matches, every
    /// following press would do the same — leaving no way to recover but switching
    /// channels. Treating a failed item as "not loaded" restarts the stream instead.
    var hasLoadedItem: Bool {
        guard let item = player?.currentItem else { return false }
        return item.status != .failed
    }

    /// Called by DRServiceManager so the remote play/togglePlayPause commands
    /// can start playback when no item is loaded (e.g. restored from cache).
    var onRequestPlay: (() -> Void)?

    /// When the current pause began, so resume() can tell a momentary pause from one long
    /// enough that a live stream's buffered window has gone stale.
    private var pausedAt: Date?

    /// Past this, a paused live item is reloaded instead of resumed. `play()` on an
    /// `AVPlayerItem` whose live window has moved on can leave it stalled with no error.
    private static let staleAfter: TimeInterval = 10

    func resume() {
        Log.playback.info("resume() requested")
        let url = (player?.currentItem?.asset as? AVURLAsset)?.url
        // Inside the DVR window, a pause is a time-shift: carry on from where it stopped,
        // and "Live" is there to jump forward. Past the window — or on a stream without
        // one — the position is gone, so reload at live.
        if let pausedAt, Date().timeIntervalSince(pausedAt) > Self.staleAfter,
           !positionIsInsideWindow, let url {
            Log.playback.info("resuming after a long pause; reloading the live stream")
            play(url: url)
            return
        }
        pausedAt = nil
        wantsPlayback = true

            // Session activation is off the main thread: setActive(true) can block, and
            // AVAudioSession warns when it is called there. play() waits for it, since
            // starting against an inactive session is what failed silently before.
        activateSession(context: "resume") { [weak self] _ in
            guard let self, let player = self.player else { return }
            player.play()
            self.isPlaying = true
            self.updateCommandCenterPlaybackState()
            self.verifyResumed(player, reloadingWith: url)
        }
    }

    // MARK: - Audio session

    /// Where the audio session is activated and deactivated. `setActive` can block, and
    /// AVAudioSession warns whenever it is called on the main thread — every press of play
    /// did. Serial, so the calls land in the order they were made: a stop's deactivation
    /// must never overtake the next play's activation.
    private let sessionQueue = DispatchQueue(label: "lytter.audio-session", qos: .userInitiated)

    /// Activates the playback session on `sessionQueue`, then runs `then` on main with
    /// whether it succeeded. A failure is logged; most callers carry on regardless, since a
    /// session that is already active reports no error and trying to play beats silence.
    /// `longFormAudio` asks for the long-form route-sharing policy, as the interruption
    /// path always has. A Bool rather than the policy itself, which macOS does not have.
    private func activateSession(longFormAudio: Bool = false,
                                 context: StaticString,
                                 then: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        #if os(iOS) || os(tvOS)
        sessionQueue.async {
            var activated = true
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default,
                                             policy: longFormAudio ? .longFormAudio : .default)
                try audioSession.setActive(true)
            } catch {
                activated = false
                Log.playback.error(
                    "could not activate the audio session (\(context, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            }
            if let then { Task { @MainActor in then(activated) } }
        }
        #else
        if let then { Task { @MainActor in then(true) } }
        #endif
    }

    /// Releases the session on `sessionQueue`, so other apps' audio can come back.
    private func deactivateSession() {
        #if os(iOS) || os(tvOS)
        sessionQueue.async {
            do {
                try AVAudioSession.sharedInstance()
                    .setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                Log.playback.error(
                    "could not deactivate the audio session: \(error.localizedDescription, privacy: .public)")
            }
        }
        #endif
    }

    /// Reloads the stream if the listener wants audio and the player is not producing it.
    ///
    /// For when the connection comes back. A live HLS item that ran dry while offline sits
    /// in `.waitingToPlayAtSpecifiedRate` with no error and does not always pick up again on
    /// its own, and from the outside that is indistinguishable from playing: `isPlaying` is
    /// still true. Returns whether it reloaded.
    @discardableResult
    func reloadIfStalled() -> Bool {
        guard wantsPlayback, let player, player.timeControlStatus != .playing,
              let url = (player.currentItem?.asset as? AVURLAsset)?.url else { return false }
        Log.playback.info("connection back with the stream not playing; reloading it")
        play(url: url)
        return true
    }

    /// `play()` on a paused item can leave it stalled with no error — either back at
    /// `.paused`, or forever in `.waitingToPlayAtSpecifiedRate` on a live window that has
    /// moved on. If it is not actually playing a few seconds later, reload the stream.
    private func verifyResumed(_ player: AVPlayer, reloadingWith url: URL?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.player === player, self.isPlaying,
                  player.timeControlStatus != .playing, let url else { return }
            Log.playback.error(
                "resume did not start audio (status \(player.timeControlStatus.rawValue), waiting: \(player.reasonForWaitingToPlay?.rawValue ?? "none", privacy: .public), error: \(player.currentItem?.error?.localizedDescription ?? "none", privacy: .public)); reloading the stream")
            self.play(url: url)
        }
    }
    
    func stop() {
        wantsPlayback = false
        player?.pause()
        playerObservations.removeAll()
        removeTimeObserver()
        player = nil
        refreshSeekState()
        isPlaying = false
        interruption.playbackSettledDeliberately()
        duration = 0
            // Clear Command Center info
        clearCommandCenterInfo()
        
        deactivateSession()
    }
    
    // MARK: - Seeking within the DVR window

    /// How far one press of skip moves, on screen and on the lock screen alike.
    static let skipInterval: TimeInterval = 15

    /// Closer to the live edge than this counts as live. Playback starts a few seconds
    /// short of the edge by design, so zero would never be reached.
    private static let liveTolerance: TimeInterval = 10

    /// The window AVPlayer can seek within, or nil when there is none worth offering.
    private var seekableRange: CMTimeRange? {
        guard let range = player?.currentItem?.seekableTimeRanges.last?.timeRangeValue,
              range.isValid, range.duration.seconds > Self.skipInterval * 2 else { return nil }
        return range
    }

    /// Moves playback by `seconds`, kept inside the window. Forward stops at live.
    func skip(by seconds: TimeInterval) {
        guard let range = seekableRange, let player else { return }
        let target = min(max(player.currentTime().seconds + seconds, range.start.seconds),
                         range.end.seconds)
        seek(to: target)
    }

    /// Jumps to the live edge.
    func seekToLive() {
        guard let range = seekableRange else { return }
        seek(to: range.end.seconds)
    }

    private func seek(to seconds: TimeInterval) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        let tolerance = CMTime(seconds: 1, preferredTimescale: 600)
        player?.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshSeekState() }
        }
    }

    /// True when the current position is still inside the window, so a paused stream can
    /// carry on from where it stopped rather than being reloaded at live.
    private var positionIsInsideWindow: Bool {
        guard let range = seekableRange, let time = player?.currentTime(), time.isValid else {
            return false
        }
        return range.containsTime(time)
    }

    /// The window's end as last seen, and when. See `estimatedLiveEdge(for:)`.
    private var liveEdgeSample: (end: TimeInterval, at: Date)?

    /// Where live is now, between playlist refreshes.
    ///
    /// The window's end does not move smoothly: it jumps forward a segment at a time when
    /// the playlist reloads (about every 7 s on DR), while the playhead moves continuously.
    /// Measured against the raw end, "behind live" was a sawtooth with that amplitude, and
    /// 15 s back — one skip — straddled the threshold, so Live and skip-forward flickered
    /// on and off with every refresh. Projecting the last end forward at 1 s/s keeps the
    /// distance steady while playing; a fresh end that overtakes the projection replaces it.
    private func estimatedLiveEdge(for range: CMTimeRange) -> TimeInterval {
        let now = Date()
        let end = range.end.seconds
        if let sample = liveEdgeSample {
            let projected = sample.end + now.timeIntervalSince(sample.at)
            // A window that is far behind the projection is a new stream, not a late
            // refresh: start again from it.
            if end <= projected, projected - end < Self.skipInterval * 2 {
                return projected
            }
        }
        liveEdgeSample = (end, now)
        return end
    }

    private func refreshSeekState() {
        let range = seekableRange
        let behind: Bool
        if let range, let time = player?.currentTime(), time.isValid {
            behind = estimatedLiveEdge(for: range) - time.seconds > Self.liveTolerance
        } else {
            behind = false
        }
        // Assign only on change: this runs every second, and each write to a published
        // property redraws every view observing it.
        if canSeek != (range != nil) {
            canSeek = range != nil
            updateSkipCommandsEnabled()
        }
        if isBehindLive != behind { isBehindLive = behind }
        let offset: TimeInterval
        if behind, let range, let time = player?.currentTime() {
            offset = (estimatedLiveEdge(for: range) - time.seconds).rounded()
        } else {
            offset = 0
        }
        if secondsBehindLive != offset { secondsBehindLive = offset }
    }

    private func addTimeObserver() {
        guard let player else { return }
        let token = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main
        ) { [weak self] _ in
            // The closure is not main-actor isolated by type, but `queue: .main` is where
            // it runs: say so, rather than call main-actor state from a nonisolated context.
            MainActor.assumeIsolated { self?.refreshSeekState() }
        }
        timeObserver = (player, token)
    }

    private func removeTimeObserver() {
        if let (owner, token) = timeObserver {
            owner.removeTimeObserver(token)
        }
        timeObserver = nil
        liveEdgeSample = nil
    }
    
    func setVolume(_ volume: Float) {
        player?.volume = volume
    }
    
        // MARK: - Screen Sleep Control
    
    func setPreventScreenSleep(_ prevent: Bool) {
        preventScreenSleep = prevent
        updateIdleTimer()
    }
} 
