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

    // MARK: - iOS Audio Player Service

class AudioPlayerService: NSObject, ObservableObject {
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
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
    
    override init() {
        super.init()
        setupCommandCenter()
        setupAudioInterruptionHandling()
            // Allow screen sleep by default on app launch
        setPreventScreenSleep(false)
            // Audio session will be setup when first needed
    }
    
    deinit {
        removeTimeObserver()
        
            // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        
            // Clean up Command Center
        cleanupCommandCenter()
    }
    
    private var audioSessionSetup = false
    private var wasPlayingBeforeInterruption = false
    
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
            wasPlayingBeforeInterruption = isPlaying
            if isPlaying {
                pause()
            }
            
        case .ended:
            // Audio interruption ended
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) && wasPlayingBeforeInterruption {
                // Resume playback if it was playing before interruption
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
            // Audio output device was disconnected (e.g., headphones unplugged)
            if isPlaying {
                pause()
            }
            
        case .newDeviceAvailable:
            // New audio output device available
            // Optionally resume if it was playing before
            if wasPlayingBeforeInterruption {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.resumeAfterInterruption()
                }
            }
            
        default:
            break
        }
    }
    
    private func resumeAfterInterruption() {
        // Only resume if we have a valid player and it was playing before interruption
        guard let player = player, wasPlayingBeforeInterruption else {
            return
        }
        
        // Reactivate audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, policy: .longFormAudio)
            try audioSession.setActive(true)
        } catch {
            print("Failed to reactivate audio session after interruption: \(error)")
            return
        }
        
        // Resume playback
        player.play()
        isPlaying = true
        wasPlayingBeforeInterruption = false
        
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
            // Get the shared command center
        commandCenter = MPRemoteCommandCenter.shared()
        nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        
            // Configure play command
        commandCenter?.playCommand.addTarget { [weak self] _ in
            self?.resume()
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
            if self?.isPlaying == true {
                self?.pause()
            } else {
                self?.resume()
            }
            return .success
        }
        
            // Configure skip backward command (1 second interval for live radio)
        commandCenter?.skipBackwardCommand.preferredIntervals = [30]
        commandCenter?.skipBackwardCommand.isEnabled = true
        commandCenter?.skipBackwardCommand.addTarget { [weak self] event in
            self?.skipBackward(by: 30)
            return .success
        }
        
            // Configure skip forward command (1 second interval for live radio)
        commandCenter?.skipForwardCommand.preferredIntervals = [1]
        commandCenter?.skipForwardCommand.isEnabled = true
        commandCenter?.skipForwardCommand.addTarget { [weak self] event in
            self?.skipForward()
            return .success
        }
        
            // Configure seeking commands for live radio
        commandCenter?.seekForwardCommand.isEnabled = true
        commandCenter?.seekBackwardCommand.isEnabled = true
        commandCenter?.changePlaybackPositionCommand.isEnabled = true
        
            // Set up seek forward command
        commandCenter?.seekForwardCommand.addTarget { [weak self] event in
            self?.skipForward()
            return .success
        }
        
            // Set up seek backward command
        commandCenter?.seekBackwardCommand.addTarget { [weak self] event in
            self?.skipBackward(by: 30)
            return .success
        }
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
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let data = data, let image = UIImage(data: data) {
                    completion(image)
                } else {
                    completion(nil)
                }
            }
        }.resume()
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
        
            // Enable/disable skip commands based on playback state
        commandCenter?.skipForwardCommand.isEnabled = isPlaying
        commandCenter?.skipBackwardCommand.isEnabled = isPlaying
        commandCenter?.seekForwardCommand.isEnabled = isPlaying
        commandCenter?.seekBackwardCommand.isEnabled = isPlaying
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
        wasPlayingBeforeInterruption = false
        
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
        
            // Remove existing time observer
        removeTimeObserver()
        
            // Create new player
        player = AVPlayer(playerItem: playerItem)
        
            // Add time observer with longer interval to allow screen sleep
        let interval = CMTime(seconds: 5.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }
        
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
            .store(in: &cancellables)
        
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
            .store(in: &cancellables)
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        
        // Only reset the interruption flag if this is a manual pause (not due to interruption)
        if !wasPlayingBeforeInterruption {
            wasPlayingBeforeInterruption = false
        }
        
            // Deactivate audio session when pausing to allow screen sleep
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
                // Silent error handling
        }
        
        // Update Command Center playback state
        updateCommandCenterPlaybackState()
    }
    
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
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        removeTimeObserver()
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
    
    private func removeTimeObserver() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }
    
    func setVolume(_ volume: Float) {
        player?.volume = volume
    }
    
        // MARK: - Screen Sleep Control
    
    func setPreventScreenSleep(_ prevent: Bool) {
        preventScreenSleep = prevent
        updateIdleTimer()
    }
    
        // MARK: - Skip Functionality
    
    func skipForward() {
            // For live radio, skip forward means jump to the live position
            // This effectively "catches up" to the live stream
        if let player = player {
                // For live radio, seek to the end of the stream (live position)
                // This will jump to the current live broadcast
            player.seek(to: .positiveInfinity)
            
                // Update the command center to reflect we're at live position
            updateCommandCenterPlaybackState()
        }
    }
    
    func skipBackward(by interval: TimeInterval) {
            // For live radio, skip backward jumps to the beginning of the current stream
            // This effectively "restarts" the current live broadcast
        if let player = player {
                // Jump to the beginning of the current stream (0 seconds)
            let startTime = CMTime(seconds: 0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            player.seek(to: startTime)
            
                // Update the command center to reflect we're at the beginning
            updateCommandCenterPlaybackState()
        }
    }
    
    
} 
