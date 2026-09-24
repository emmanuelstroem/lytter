    //
    //  AudioPlayerService.swift
    //  ios
    //
    //  Created by Emmanuel on 27/07/2025.
    //

import Foundation
import AVFoundation
import Combine
import UIKit
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
    
    @Published var isPlaying = false
    @Published var duration: TimeInterval = 0
    @Published var isLoading = false
    @Published var error: String?
    
        // Control for screen sleep behavior
    @Published var preventScreenSleep = false
    
        // AirPlay properties
    @Published var isAirPlayActive = false
    @Published var currentAirPlayRoute: AVAudioSessionRouteDescription?
    
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
        setupAudioInterruptionHandling()
            // Allow screen sleep by default on app launch
        setPreventScreenSleep(false)
            // Audio session will be setup when first needed
    }
    
    deinit {
            // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        
            // Clean up Command Center
        cleanupCommandCenter()
    }
    
    private var audioSessionSetup = false
    private var interruption = InterruptionState()
    
    // MARK: - Audio Interruption Handling
    
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
        guard let player = player else { return }
        
        // Reactivate audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, policy: .longFormAudio)
            try audioSession.setActive(true)
        } catch {
            Log.playback.error(
                "could not reactivate the audio session after an interruption: \(error.localizedDescription, privacy: .public)")
            return
        }
        
        // Resume playback
        player.play()
        isPlaying = true
        
        // Update Command Center playback state
        updateCommandCenterPlaybackState()
    }
    
        // MARK: - Screen Sleep Control
    
    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = preventScreenSleep
    }
    
        // MARK: - AirPlay Support
    
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

        // Configure play command
        commandCenter?.playCommand.addTarget { [weak self] _ in
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
            self?.pause()
            return .success
        }

        // Configure stop command (acts like pause for live radio)
        commandCenter?.stopCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        // Configure toggle play/pause command
        commandCenter?.togglePlayPauseCommand.addTarget { [weak self] _ in
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

        // Skip and seek are disabled rather than wired up. These are live ICY streams
        // with no seekable range, so the old handlers — seek(to: .zero) and
        // seek(to: .positiveInfinity) — did nothing at all, while the commands were
        // advertised as enabled. The lock screen and Control Centre showed skip buttons
        // that silently ignored every press. Better to not offer them.
        commandCenter?.skipBackwardCommand.isEnabled = false
        commandCenter?.skipForwardCommand.isEnabled = false
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
    
    func updateCommandCenterInfo(channel: DRChannel, program: DREpisode?, track: DRTrack? = nil) {
        var nowPlayingInfo: [String: Any] = [:]
        
            // Determine what to show as title and artist based on available information
        if let track = track, track.isCurrentlyPlaying {
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
                    nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
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
    
    private func loadImageForCommandCenter(from url: URL, completion: @escaping (UIImage?) -> Void) {
        // Through the cache: this runs on every now-playing metadata update — each track
        // change, each programme change — and it is almost always the same artwork the
        // player screen is already showing.
        ImageCacheService.shared.loadImage(from: url.absoluteString, completion: completion)
    }
    
    private func setDefaultCommandCenterArtwork(nowPlayingInfo: [String: Any]) {
        var updatedInfo = nowPlayingInfo
        
            // Create a simple default artwork with radio icon
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let defaultImage = renderer.image { context in
                // Background gradient
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor] as CFArray,
                                      locations: [0.0, 1.0])!
            
            context.cgContext.drawLinearGradient(gradient,
                                                 start: CGPoint(x: 0, y: 0),
                                                 end: CGPoint(x: size.width, y: size.height),
                                                 options: [])
            
                // Radio icon
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
        
        updatedInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: defaultImage.size) { _ in defaultImage }
        nowPlayingInfoCenter?.nowPlayingInfo = updatedInfo
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
        isLoading = true
        error = nil
        // Starting a channel is deliberate, so any pending resume intent is void.
        interruption.playbackSettledDeliberately()
        
            // Setup and activate audio session when starting playback
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
                // Set category first
            try audioSession.setCategory(.playback, mode: .default)
            
                // Then activate
            try audioSession.setActive(true)
            
                // Setup AirPlay monitoring if not already done
            if !audioSessionSetup {
                setupAirPlayMonitoring()
                audioSessionSetup = true
            }
        } catch {
                // Silent error handling
        }
        
            // Create new player item
        let playerItem = AVPlayerItem(url: url)

            // Tear down everything tied to the outgoing player before replacing it.
            // The two sinks below capture their AVPlayerItem and subscribe to their
            // AVPlayer, so leaving them subscribed kept one of each alive per channel
            // switch — and each one carried on writing isPlaying/isLoading on this
            // service. A discarded player reaching .paused would then flip the UI to
            // "paused" while the channel the user just chose was playing.
        playerObservations.removeAll()

        // Create new player
        player = AVPlayer(playerItem: playerItem)

        #if os(tvOS)
        if let player = player {
            rebindCommandCenterToNowPlayingSessionIfNeeded(for: player)
        }
        #endif
        
            // No periodic time observer. It fired every 5 seconds to write `currentTime`,
            // which no view reads — live radio has no meaningful elapsed position, and
            // the two players that show a progress bar drive it from their own @State.
        
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

    func resume() {
        player?.play()
        isPlaying = true
        
            // Reactivate audio session when resuming
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
                // Ensure category is set correctly
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
                // Silent error handling
        }
        
            // Update Command Center playback state
        updateCommandCenterPlaybackState()
    }
    
    func stop() {
        player?.pause()
        playerObservations.removeAll()
        player = nil
        isPlaying = false
        interruption.playbackSettledDeliberately()
        duration = 0
            // Clear Command Center info
        clearCommandCenterInfo()
        
            // Deactivate audio session when stopping playback
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
                // Silent error handling
        }
    }
    
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: cmTime)
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
