//
//  DRServiceManager.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import Foundation
import SwiftUI
import Combine
import os
#if os(tvOS)
import TVServices
#endif

// MARK: - Service Manager
class DRServiceManager: ObservableObject {
    /// The app's one manager.
    ///
    /// Static rather than created by the scene, because an App Intent (F15) can start the
    /// app with no scene at all — Siri, the Action Button or a Shortcuts automation
    /// launching it in the background to play a station. lytterApp hands this same
    /// instance to every screen, so what the intent starts is what the screens show.
    static let shared = DRServiceManager()

    // Direct observable properties
    @Published var availableChannels: [DRChannel] = []
    @Published var isLoading = false
    /// Why the last catalogue fetch failed, or nil once one succeeds. Views read
    /// `connectionProblem`, not this.
    @Published private(set) var catalogueFailure: RequestFailure?
    /// Whether the device has a route to the internet. Assumed until `NetworkMonitor` says.
    @Published private(set) var isOnline = true
    /// True once a fetch with nothing on screen has run past `ConnectionTiming.slowAfter`.
    @Published private(set) var isWaitingLong = false
    /// The broadcasters the listener has not hidden, in their order (F54b). Only these are
    /// fetched, so a hidden one leaves every screen without any of them asking.
    @Published private(set) var visibleBroadcasters: [Broadcaster] = []
    
    @Published var playingChannel: DRChannel?
    @Published var currentLiveProgram: DREpisode?
    @Published var currentTrack: DRTrack?
    @Published var isPlaying = false
    /// Mirrors AudioPlayerService: whether the stream can be skipped within, and whether
    /// playback is behind live. Views observe this manager, not the player.
    @Published private(set) var canSeek = false
    @Published private(set) var isBehindLive = false
    /// How far behind live playback is, in whole seconds; 0 at live or on ICY.
    @Published private(set) var secondsBehindLive: TimeInterval = 0
    @Published var playbackError: String? // Separate error for playback issues

    /// The recording being listened back to, while catch-up plays instead of the live
    /// stream (F16). `playingChannel` stays its channel, so the mini player, the cards and
    /// SharePlay go on naming the station; `getCurrentProgram` answers with this.
    @Published private(set) var onDemandEpisode: DREpisode?
    /// Where playback is in the recording, in whole seconds, and how long it is. Both 0
    /// outside on-demand: a live stream has no position worth showing.
    @Published private(set) var onDemandPosition: TimeInterval = 0
    @Published private(set) var onDemandDuration: TimeInterval = 0

    let audioPlayer = AudioPlayerService()
    /// One of each registered broadcaster's sources. See `BroadcasterRegistry`.
    private let sources = BroadcasterRegistry.makeSources()
    /// DR is asked for more than its catalogue — a channel's day, its tracks, catch-up —
    /// and those calls live here until this manager is split (F54d).
    private lazy var dr: DRSource = sources.lazy.compactMap { $0 as? DRSource }.first ?? DRSource()
    private var networkService: DRNetworkService { dr.network }
    private let imageCache = ImageCacheService.shared
    let userPreferences = UserPreferencesService()
    /// When favourite shows are on (F33). Views observe it directly.
    let showSchedule = ShowScheduleService()
    #if os(iOS) || os(macOS)
    /// Reminders before favourite shows start (F51). tvOS shows no notifications but badges.
    private let showReminders = ShowReminderScheduler()
    #endif
    #if os(iOS)
    /// The widgets and the Control Centre control (F18).
    private let listeningSurfaces = ListeningSurfaces()
    #endif
    private var cancellables = Set<AnyCancellable>()
    
    // Caching properties
    private var cachedSchedules: [DREpisode] = [] {
        didSet { schedulesByChannel = Self.indexByChannel(cachedSchedules) }
    }
    /// `cachedSchedules` by channel id, rebuilt whenever it is replaced. The programme
    /// lookups run from view bodies — every card, several times per now-playing render —
    /// and each used to filter the whole schedule.
    private var schedulesByChannel: [String: [DREpisode]] = [:]
    private var lastSchedulesUpdate: Date?
    private let cacheValidityDuration: TimeInterval = 10 * 60 // 10 minutes
    
    // Track polling properties
    private var nextLivePollingTime: Date?
    private var isPollingForTrack = false
    
    private let networkMonitor = NetworkMonitor()

    init() {
        visibleBroadcasters = userPreferences.visibleBroadcasters
        setupBindings()
        #if os(iOS)
        startListeningSurfaces()
        #endif
        loadDiskCache()   // Populate UI instantly from disk
        loadChannels()    // Refresh from API in background
        networkMonitor.start { [weak self] online in self?.networkPathChanged(online: online) }
        startScheduleRefresh()
    }

    #if os(iOS)
    /// Not under UI tests, whose fixtures would otherwise be what the simulator's widgets
    /// show from then on.
    private func startListeningSurfaces() {
        #if DEBUG
        if UITestFixtures.isActive { return }
        #endif
        listeningSurfaces.start(observing: self)
    }
    #endif

    /// Synchronously loads the last persisted schedules so the UI is populated
    /// immediately on launch without waiting for the network.
    private func loadDiskCache() {
        #if DEBUG
        // UI tests start from their fixtures alone, not from whatever the simulator cached.
        let schedules = UITestFixtures.isActive
            ? (UITestFixtures.seedsCache ? UITestFixtures.schedules() : [])
            : DRLocalCache.shared.load()
        #else
        let schedules = DRLocalCache.shared.load()
        #endif
        let shownSchedules = shown(schedules)
        guard !shownSchedules.isEmpty else { return }
        cachedSchedules = shownSchedules
        availableChannels = Array(Set(shownSchedules.map { $0.channel }))
            .sorted { $0.title < $1.title }
        for source in sources {
            source.restore(from: availableChannels.filter {
                Broadcaster.supplying($0) == type(of: source).broadcaster
            })
        }
        restoreLastPlayedChannel()
    }
    
    private func setupBindings() {
        // Hiding, showing or reordering broadcasters in Settings. Both values are passed
        // on, being published before either property changes.
        userPreferences.$broadcasterOrder
            .combineLatest(userPreferences.$hiddenBroadcasterIDs)
            .dropFirst()
            .sink { [weak self] order, hidden in
                self?.broadcastersChanged(to: Broadcaster.visible(
                    registered: BroadcasterRegistry.broadcasters, order: order, hidden: hidden))
            }
            .store(in: &cancellables)
        // A show pinned on a channel not fetched today — on a constrained network, where
        // only favourite shows' channels are — needs today's schedule to say when it is on.
        // The new value is passed on: @Published publishes before the property changes.
        userPreferences.$favouriteShows
            .dropFirst()
            .sink { [weak self] shows in self?.refreshShowSchedule(favourites: shows) }
            .store(in: &cancellables)
        // Switching reminders on or off schedules them, or takes them away, at once.
        userPreferences.$remindsShows
            .dropFirst()
            .sink { [weak self] reminds in self?.rescheduleShowReminders(enabled: reminds) }
            .store(in: &cancellables)

        audioPlayer.$isPlaying
            .assign(to: \.isPlaying, on: self)
            .store(in: &cancellables)

        audioPlayer.$canSeek
            .assign(to: \.canSeek, on: self)
            .store(in: &cancellables)
        audioPlayer.$isBehindLive
            .assign(to: \.isBehindLive, on: self)
            .store(in: &cancellables)
        // Skipping, pausing and jumping to live all move the moment being heard, so the
        // track and programme are picked again — from what is already fetched, no network.
        audioPlayer.$secondsBehindLive
            .removeDuplicates()
            .sink { [weak self] seconds in
                self?.secondsBehindLive = seconds
                self?.reselectHeard()
            }
            .store(in: &cancellables)

        // Route audio errors to playbackError, not the general error shown in the channel list
        audioPlayer.$error
            .assign(to: \.playbackError, on: self)
            .store(in: &cancellables)

        audioPlayer.$position
            .removeDuplicates()
            .assign(to: \.onDemandPosition, on: self)
            .store(in: &cancellables)
        audioPlayer.$duration
            .map { $0.isFinite ? $0 : 0 }
            .removeDuplicates()
            .sink { [weak self] seconds in
                guard let self else { return }
                // The item's length once it is known, the schedule's until then.
                self.onDemandDuration = seconds > 0 ? seconds : (self.onDemandEpisode?.duration ?? 0)
            }
            .store(in: &cancellables)

        // When the remote play command fires but no item is loaded (e.g. restored
        // from cache), delegate back so a fresh stream is started.
        audioPlayer.onRequestPlay = { [weak self] in
            self?.restartPlayback()
        }
    }

    /// Starts again whatever the player was last given: the recording, from where it had
    /// got to, or the playing channel live. Every path that brings a dead or never-started
    /// item back comes through here, so none of them turns a catch-up into the live stream.
    private func restartPlayback() {
        if let episode = onDemandEpisode {
            playOnDemand(episode, from: onDemandPosition)
        } else if let channel = playingChannel {
            playChannel(channel)
        }
    }
    
    private func isCacheValid() -> Bool {
        guard let lastUpdate = lastSchedulesUpdate else { return false }
        return Date().timeIntervalSince(lastUpdate) < cacheValidityDuration
    }
    
    /// The catalogue fetch in flight, if any. Every screen's `onAppear` asks for the
    /// catalogue when it has none, and before this each ask started a fetch of its own.
    private var catalogueTask: Task<Void, Never>?
    /// The next automatic retry while DR is not answering, and how many have run.
    private var retryTask: Task<Void, Never>?
    private var retryAttempt = 0

    /// Refreshes the catalogue unless what is in memory is recent enough.
    func loadChannels() {
        // In-memory cache still valid — nothing to do
        if !cachedSchedules.isEmpty && isCacheValid() { return }
        startCatalogueFetch()
    }

    /// What every Try Again does: fetch whatever failed now, whatever the cache says.
    func retry() {
        if playbackError != nil, playingChannel != nil {
            playbackError = nil
            restartPlayback()
        }
        if catalogueFailure != nil || availableChannels.isEmpty {
            retryAttempt = 0
            startCatalogueFetch()
        }
    }

    @discardableResult
    private func startCatalogueFetch() -> Task<Void, Never> {
        if let catalogueTask { return catalogueTask }

        retryTask?.cancel()
        retryTask = nil
        // Only show loading spinner when there is no data at all (first launch)
        isLoading = availableChannels.isEmpty
        let task = Task { [weak self] in
            guard let self else { return }
            await self.fetchCatalogue()
            self.catalogueTask = nil
            self.isLoading = false
            self.isWaitingLong = false
        }
        catalogueTask = task
        if isLoading { watchForSlowAnswer(to: task) }
        return task
    }

    /// Says "still waiting" if the fetch with nothing on screen runs long, so a slow DR
    /// does not look like a stuck app.
    private func watchForSlowAnswer(to task: Task<Void, Never>) {
        Task { [weak self] in
            try? await Task.sleep(for: ConnectionTiming.slowAfter)
            guard let self, self.catalogueTask == task, self.isLoading else { return }
            self.isWaitingLong = true
        }
    }

    private func fetchCatalogue() async {
        do {
            // Filtered again on the way back: a broadcaster hidden while the fetch was out
            // is not shown by its answer.
            let schedules = shown(try await Catalogue.fetch(from: visibleSources))
            let channels = Array(Set(schedules.map { $0.channel })).sorted { $0.title < $1.title }

            self.cachedSchedules = schedules
            self.lastSchedulesUpdate = Date()
            self.availableChannels = channels
            self.catalogueFailure = nil
            self.retryAttempt = 0
            self.restoreLastPlayedChannel()
            self.refreshCurrentProgram()
            if self.isAppActive { self.refreshShowSchedule() }

            // Persist to disk only after a confirmed successful response — and never
            // fixtures, which would otherwise greet the next ordinary launch.
            #if DEBUG
            if !UITestFixtures.isActive { DRLocalCache.shared.save(schedules) }
            #else
            DRLocalCache.shared.save(schedules)
            #endif

            await self.preloadChannelImages(from: schedules)
        } catch {
            Log.network.error("catalogue fetch failed: \(error.localizedDescription, privacy: .public)")
            // Kept whether or not there are channels to show. It used to be dropped when
            // the disk cache had filled the screen, which left a listener looking at
            // yesterday's programmes with nothing to say they were not today's.
            self.catalogueFailure = RequestFailure(error)
            self.scheduleAutomaticRetry()
        }
    }

    // MARK: - Broadcasters (F54b)

    /// The sources of the broadcasters shown. A hidden one is not asked.
    private var visibleSources: [any BroadcasterSource] {
        let ids = Set(visibleBroadcasters.map(\.id))
        return sources.filter { ids.contains(type(of: $0).broadcaster.id) }
    }

    /// `schedules` without the broadcasters that are hidden.
    private func shown(_ schedules: [DREpisode]) -> [DREpisode] {
        let ids = Set(visibleBroadcasters.map(\.id))
        return schedules.filter { ids.contains(Broadcaster.supplying($0.channel).id) }
    }

    /// A hidden broadcaster's channels leave at once; one shown again is fetched at once,
    /// having nothing in memory to show until then. What is playing carries on either way.
    private func broadcastersChanged(to visible: [Broadcaster]) {
        let wereShown = Set(visibleBroadcasters.map(\.id))
        visibleBroadcasters = visible
        let ids = Set(visible.map(\.id))
        cachedSchedules = shown(cachedSchedules)
        availableChannels = availableChannels.filter { ids.contains(Broadcaster.supplying($0).id) }

        guard visible.contains(where: { !wereShown.contains($0.id) }) else { return }
        lastSchedulesUpdate = nil
        // A fetch already out was asked of the old set; this one follows it.
        if let inFlight = catalogueTask {
            Task { [weak self] in
                await inFlight.value
                self?.startCatalogueFetch()
            }
        } else {
            startCatalogueFetch()
        }
    }

    /// While DR is not answering, asks again on a widening interval. Offline is left to
    /// `networkPathChanged`, which knows when it is worth asking.
    private func scheduleAutomaticRetry() {
        guard isOnline, case .drUnavailable = catalogueFailure, retryTask == nil else { return }
        let delay = ConnectionTiming.retryDelay(afterAttempt: retryAttempt)
        retryAttempt += 1
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.retryTask = nil
            Log.network.info("retrying the catalogue while DR is not answering")
            self.startCatalogueFetch()
        }
    }

    /// The connection came or went.
    private func networkPathChanged(online: Bool) {
        guard online != isOnline else { return }
        Log.network.info("network path is \(online ? "online" : "offline", privacy: .public)")
        isOnline = online
        guard online else {
            retryTask?.cancel()
            retryTask = nil
            return
        }
        // Back: fetch what failed or never came, and restart a stream that died with it.
        retryAttempt = 0
        if catalogueFailure != nil || availableChannels.isEmpty || !isCacheValid() {
            startCatalogueFetch()
        }
        if playbackError != nil, audioPlayer.wantsPlayback, playingChannel != nil {
            playbackError = nil
            restartPlayback()
        } else {
            audioPlayer.reloadIfStalled()
        }
    }

    /// What to tell the listener about the connection, if anything. See `ConnectionProblem`.
    var connectionProblem: ConnectionProblem? {
        ConnectionProblem.current(isOnline: isOnline,
                                  catalogueFailure: catalogueFailure,
                                  failedStream: playbackError == nil ? nil : playingChannel?.title)
    }

    /// Whether `channel` can be heard right now.
    ///
    /// Not the same as being `playingChannel`, which names whatever is loaded in the player:
    /// a paused channel, and the last-played channel restored at launch without being
    /// started. Marking that one with a speaker left the mark on a card long after the
    /// sound had stopped.
    func isAudible(_ channel: DRChannel) -> Bool {
        Self.isAudible(channel, loaded: playingChannel, isPlaying: isPlaying)
    }

    static func isAudible(_ channel: DRChannel, loaded: DRChannel?, isPlaying: Bool) -> Bool {
        isPlaying && loaded?.id == channel.id
    }

    func togglePlayback(for channel: DRChannel) {
        if playingChannel?.id == channel.id {
            if isPlaying {
                audioPlayer.pause()
                stopPolling()
                audioPlayer.updateCommandCenterPlaybackState()
            } else if audioPlayer.hasLoadedItem {
                // Player item exists — just resume from where it paused
                audioPlayer.resume()
                // A recording has no live track to follow.
                if onDemandEpisode == nil { startPolling(for: channel) }
                audioPlayer.updateCommandCenterPlaybackState()
            } else {
                // Restored from cache but never played this session, or the item failed —
                // start fresh, as whatever it was: the recording, or the channel live.
                restartPlayback()
            }
        } else {
            playChannel(channel)
        }
    }
    
    func skip(by seconds: TimeInterval) {
        audioPlayer.skip(by: seconds)
    }

    /// Back to live: the live edge of the DVR window, or out of a recording and onto the
    /// channel's stream, which is the live control's meaning in either case.
    func seekToLive() {
        if onDemandEpisode != nil, let channel = playingChannel {
            playChannel(channel)
        } else {
            audioPlayer.seekToLive()
        }
    }

    /// Moves the recording to `seconds` from its start. Live has nowhere to scrub to.
    func seekOnDemand(to seconds: TimeInterval) {
        guard onDemandEpisode != nil else { return }
        audioPlayer.seek(toPosition: seconds)
    }

    func stopPlayback() {
        audioPlayer.stop()
        onDemandEpisode = nil
        playingChannel = nil
        currentTrack = nil
        currentLiveProgram = nil
        stopPolling()
        
        // Clear command center info
        audioPlayer.clearCommandCenterInfo()
        
        // Notify observers that playback has stopped
        objectWillChange.send()
    }
    
    /// What selecting a channel should do, given what the player already has.
    enum SelectionAction: Equatable {
        /// Start the stream from scratch: another channel or district, or nothing usable
        /// is loaded (never started this session, or the item failed).
        case restart
        /// The selected channel is loaded and paused: carry on rather than reload.
        case resume
        /// The selected channel is already playing: leave it alone.
        case nothing
    }

    /// Selecting the station that is already on used to tear the stream down and start it
    /// again — an audible gap for nothing. Each district is its own `DRChannel` with its
    /// own `id`, so comparing ids is enough to tell "same channel and district" apart from
    /// "different channel" and "same station, different district".
    ///
    /// A recording of the channel is not the channel: choosing the station while catching
    /// up on one of its programmes means the station, live.
    static func selectionAction(for channel: DRChannel, loaded: DRChannel?,
                                hasLoadedItem: Bool, isPlaying: Bool,
                                loadedIsOnDemand: Bool = false) -> SelectionAction {
        guard loaded?.id == channel.id, hasLoadedItem, !loadedIsOnDemand else { return .restart }
        return isPlaying ? .nothing : .resume
    }

    func playChannel(_ channel: DRChannel) {
        switch Self.selectionAction(for: channel, loaded: playingChannel,
                                    hasLoadedItem: audioPlayer.hasLoadedItem,
                                    isPlaying: isPlaying,
                                    loadedIsOnDemand: onDemandEpisode != nil) {
        case .nothing:
            Log.playback.debug("selected the channel already playing; leaving it")
            return
        case .resume:
            Log.playback.debug("selected the paused channel; resuming")
            audioPlayer.resume()
            startPolling(for: channel)
            audioPlayer.updateCommandCenterPlaybackState()
            return
        case .restart:
            break
        }

        onDemandEpisode = nil
        recentTracks = []
        heardSnapshot = nil
        heardSnapshotTask?.cancel()
        heardSnapshotTask = nil

        // Switching channels: drop the previous channel's polling before starting the
        // new one, so two loops never run at once.
        stopPolling()
        
        // Get current program from cached schedules
        let currentProgram = liveProgram(for: channel)
        
        // Update UI on main actor
        Task { @MainActor in
            self.currentLiveProgram = currentProgram
            self.currentTrack = nil
            
            // Update Command Center with new program information
            if let playingChannel = self.playingChannel {
                self.audioPlayer.updateCommandCenterInfo(channel: playingChannel, program: currentProgram, track: self.currentTrack)
            }
        }
        
        // Poll the live track and refresh the programme for as long as this channel plays.
        startPolling(for: channel)
        
        // Try to get stream URL from current program first
        var streamURL: String? = currentProgram?.streamURL
        
        // If no stream URL from current program, try to get from any cached program for this channel
        if streamURL == nil {
            streamURL = getCachedPrograms(for: channel).first?.streamURL
        }
        
        // There is deliberately no hardcoded fallback here. The previous one guessed
        // https://live-icy.gss.dr.dk/AAC<SLUG>, and every URL in that family now returns
        // 404 — so it turned "we have no stream" into a stream that fails obscurely once
        // playback had already started. Failing here gives the user an honest message.

        // Play the stream
        if let finalStreamURL = streamURL,
           let url = URL(string: finalStreamURL) {
            Task { @MainActor in
                self.playingChannel = channel
                self.audioPlayer.play(url: url)
                
                // Save the last played channel
                self.userPreferences.saveLastPlayedChannel(channel)
                
                // Update Command Center with channel and program info
                let currentProgram = self.getCurrentProgram(for: channel)
                self.audioPlayer.updateCommandCenterInfo(channel: channel, program: currentProgram, track: self.currentTrack)
            }
        } else {
            Task { @MainActor in
                // Stop what was playing and name the channel that failed. Before, the
                // previous channel played on under an error about this one, and the
                // message could not say which channel it meant.
                self.audioPlayer.stop()
                self.playingChannel = channel
                self.playbackError = "No stream URL available for \(channel.title)"
            }
        }
    }

    /// Plays the recording of `episode` from `position` seconds in (F16).
    ///
    /// The live machinery stands down for it. Track polling follows the live edge, and the
    /// heard-programme lookup measures back from it; neither means anything in a recording,
    /// and left running they would replace the episode on screen with whatever is on air.
    func playOnDemand(_ episode: DREpisode, from position: TimeInterval = 0) {
        guard let string = episode.onDemandStreamURL, let url = URL(string: string) else {
            Log.playback.error("no on-demand stream for \(episode.id, privacy: .public)")
            return
        }
        Log.playback.info("playing on demand: \(episode.id, privacy: .public)")
        stopPolling()
        recentTracks = []
        heardSnapshot = nil
        heardSnapshotTask?.cancel()
        heardSnapshotTask = nil
        playbackError = nil

        onDemandEpisode = episode
        onDemandDuration = episode.duration
        playingChannel = episode.channel
        currentTrack = nil
        currentLiveProgram = episode
        audioPlayer.play(url: url, onDemand: true, from: position)
        audioPlayer.updateCommandCenterInfo(channel: episode.channel, program: episode)
    }
    
    /// The catalogue as home-screen sections, one per shown broadcaster that has channels,
    /// in the listener's order.
    ///
    /// DR is the only source today, so this is a single section — but the home screen
    /// renders whatever this returns, which is what makes adding a broadcaster a data
    /// change rather than a layout one.
    var broadcasterSections: [BroadcasterSection] {
        Broadcaster.sections(from: availableChannels, shown: visibleBroadcasters)
    }

    /// The programme the listener is hearing on `channel`.
    ///
    /// For the playing channel while behind live, that is the programme on air at the
    /// moment being heard, which near a boundary is the previous one. Every other channel,
    /// and the playing one at live, is what is on air now.
    ///
    /// While catching up, the playing channel's programme is the recording, wherever it
    /// sits in the day.
    func getCurrentProgram(for channel: DRChannel) -> DREpisode? {
        if channel.id == playingChannel?.id, let onDemandEpisode { return onDemandEpisode }
        guard channel.id == playingChannel?.id, secondsBehindLive > 0 else {
            return liveProgram(for: channel)
        }
        let date = listeningDate
        let candidates = getCachedPrograms(for: channel)
            + (heardSnapshot.flatMap { $0.channelID == channel.id ? $0.episodes : nil } ?? [])
        return Self.heardProgram(in: candidates, at: date) ?? liveProgram(for: channel)
    }

    static func heardProgram(in programmes: [DREpisode], at date: Date) -> DREpisode? {
        programmes.first { $0.isPlaying(at: date) }
    }

    /// The programme on air now, whatever the listener is hearing. For wall-clock needs:
    /// the stream to start, and when the programme ends for the sleep timer.
    func liveProgram(for channel: DRChannel) -> DREpisode? {
        Self.liveProgram(in: getCachedPrograms(for: channel), at: Date())
    }

    /// The programme on air at `date`, or failing that one whose times DR did not give,
    /// which cannot be judged either way.
    ///
    /// Never one that has ended. This fell back to whatever the channel's first cached
    /// programme was, so a launch from a day-old disk cache, or an hour of DR not answering,
    /// showed long-finished programmes as on air — on every card, the player, the lock
    /// screen, and as the end the sleep timer counted down to.
    static func liveProgram(in programmes: [DREpisode], at date: Date) -> DREpisode? {
        programmes.first { $0.isPlaying(at: date) }
            ?? programmes.first { $0.startDate == nil || $0.endDate == nil }
    }

    // MARK: - What is being heard

    /// The moment being listened to: now, less how far behind live playback is.
    var listeningDate: Date { Date().addingTimeInterval(-secondsBehindLive) }

    /// Whether `track` is what the listener hears now. Views use this rather than
    /// `isCurrentlyPlaying`, which asks about the live edge.
    func isHeard(_ track: DRTrack) -> Bool { track.isPlaying(at: listeningDate) }

    /// The last track list fetched for the playing channel, newest first. DR returns about
    /// the last hour, which covers the ~34 minute DVR window.
    private var recentTracks: [DRTrack] = []

    /// The playing channel's schedule snapshot, fetched only once the listener is behind
    /// live and earlier than the programme `/schedules/all/now` carries. Despite the
    /// endpoint's name it is not "today": it starts with the programme before the one on
    /// air, which is exactly the one a rewind across a boundary lands in.
    private var heardSnapshot: HeardSnapshot?
    private var heardSnapshotTask: Task<Void, Never>?

    struct HeardSnapshot {
        let channelID: String
        let episodes: [DREpisode]
        let fetchedAt: Date
    }

    /// After a failed or empty fetch, wait this long before asking again. Without it a
    /// failure was cached for the channel and never retried; with no wait at all, a paused
    /// listener — whose offset moves every second — would ask every second.
    static let heardSnapshotRetryInterval: TimeInterval = 60

    /// Whether the snapshot is needed and not already in hand.
    static func needsHeardSnapshot(listeningAt date: Date, liveProgrammeStart: Date?,
                                   channelID: String, have snapshot: HeardSnapshot?,
                                   now: Date) -> Bool {
        guard let liveProgrammeStart, date < liveProgrammeStart else { return false }
        guard let snapshot, snapshot.channelID == channelID else { return true }
        return snapshot.episodes.isEmpty
            && now.timeIntervalSince(snapshot.fetchedAt) >= heardSnapshotRetryInterval
    }

    static func heardTrack(in tracks: [DRTrack], at date: Date) -> DRTrack? {
        tracks.first { $0.isPlaying(at: date) }
    }

    /// Picks the track and programme for the moment being heard and publishes them if they
    /// changed.
    private func reselectHeard() {
        // A recording is one programme with no live tracks: nothing to pick.
        guard let channel = playingChannel, onDemandEpisode == nil else { return }
        let date = listeningDate
        let track = Self.heardTrack(in: recentTracks, at: date)
        loadHeardSnapshotIfNeeded(for: channel, at: date)
        let program = getCurrentProgram(for: channel)
        guard track != currentTrack || program?.id != currentLiveProgram?.id else { return }
        Log.playback.debug("heard: \(track?.title ?? "no track", privacy: .public) at \(Int(self.secondsBehindLive)) s behind live")
        currentTrack = track
        currentLiveProgram = program
        audioPlayer.updateCommandCenterInfo(channel: channel, program: program, track: track)
    }

    private func loadHeardSnapshotIfNeeded(for channel: DRChannel, at date: Date) {
        guard heardSnapshotTask == nil,
              Self.needsHeardSnapshot(listeningAt: date,
                                      liveProgrammeStart: liveProgram(for: channel)?.startDate,
                                      channelID: channel.id, have: heardSnapshot, now: Date())
        else { return }
        Log.playback.debug("behind live past the programme start; fetching the schedule snapshot")
        heardSnapshotTask = Task { [weak self] in
            guard let self else { return }
            let episodes = await self.loadSchedule(for: channel)
            await MainActor.run {
                self.heardSnapshotTask = nil
                guard self.playingChannel?.id == channel.id else { return }
                self.heardSnapshot = HeardSnapshot(channelID: channel.id, episodes: episodes,
                                                   fetchedAt: Date())
                self.reselectHeard()
            }
        }
    }
    
    /// Today's full schedule for a channel.
    ///
    /// `/schedules/all/now` only carries what is on air right now, so the rest of the
    /// day comes from the snapshot endpoint — which `DRNetworkService` has always
    /// implemented and nothing has ever called.
    func loadSchedule(for channel: DRChannel) async -> [DREpisode] {
        (try? await fetchSchedule(for: channel)) ?? []
    }

    /// As `loadSchedule`, but saying why it failed — for the schedule sheets, which used to
    /// show "No schedule" for a dead connection as if DR had nothing to list.
    func fetchSchedule(for channel: DRChannel) async throws -> [DREpisode] {
        do {
            return try await networkService.fetchScheduleSnapshot(for: channel.slug).items
        } catch {
            Log.network.error(
                "schedule snapshot failed for \(channel.slug, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// The channel's whole broadcast day so far and to come, for the schedule sheets.
    ///
    /// The snapshot alone starts with the programme before the one on air, which leaves
    /// nothing earlier to catch up on (F16). DR's day schedule has the rest; it is asked for
    /// the snapshot's own date, since DR's day turns at about 05:00 rather than midnight.
    /// Only the snapshot is required: without the day, the sheet shows what it always has.
    func fetchDaySchedule(for channel: DRChannel) async throws -> [DREpisode] {
        let snapshot: DRScheduleResponse
        do {
            snapshot = try await networkService.fetchScheduleSnapshot(for: channel.slug)
        } catch {
            Log.network.error(
                "schedule snapshot failed for \(channel.slug, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw error
        }
        guard let date = snapshot.scheduleDate else { return snapshot.items }
        do {
            let day = try await networkService.fetchDaySchedule(for: channel.slug, date: date)
            return DRScheduleResponse.mergedDay(day.items, snapshot: snapshot.items)
        } catch {
            Log.network.warning(
                "day schedule failed for \(channel.slug, privacy: .public); showing the snapshot: \(error.localizedDescription, privacy: .public)")
            return snapshot.items
        }
    }
    
    func getCachedPrograms(for channel: DRChannel) -> [DREpisode] {
        schedulesByChannel[channel.id] ?? []
    }

    /// Groups `schedules` by channel id, each channel's programmes in their original order:
    /// the lookups take the first match, so the order is part of the answer.
    static func indexByChannel(_ schedules: [DREpisode]) -> [String: [DREpisode]] {
        Dictionary(grouping: schedules, by: \.channel.id)
    }

    /// Artwork for what is on the channel now, falling back to any cached programme for it.
    ///
    /// The fallback is not hypothetical: `/schedules/all/now` returns entries with no image
    /// often enough that a card would otherwise show an empty placeholder while a perfectly
    /// good image sat in the schedule cache.
    func artworkURL(for channel: DRChannel) -> URL? {
        if let url = getCurrentProgram(for: channel)?.primaryImageURL {
            return URL(string: url)
        }
        let cached = getCachedPrograms(for: channel)
        if let url = cached.first(where: { $0.primaryImageURL != nil })?.primaryImageURL {
            return URL(string: url)
        }
        return nil
    }

    // MARK: - Deep Link Resolution

    /// Resolves the identifier carried by a deep link to a real channel.
    ///
    /// Two link formats exist and they do not agree on what identifies a channel:
    ///
    ///   - `DeepLinkHandler.generateDeepLinkURL` emits `lytter:///channel/<id>`, where id
    ///     is an opaque URN such as `urn:dr:radio:channel:5fa156d1da351264f87b462d`.
    ///   - The Top Shelf extension emits `lytter://radio/channel/<slug>`, where slug is
    ///     the short form such as `p1`.
    ///
    /// Callers previously matched on `id` only, so every Top Shelf play action silently
    /// did nothing. Accepting either form fixes that without changing the URLs already
    /// baked into the Top Shelf items the system may have cached.
    func channel(forDeepLinkIdentifier identifier: String) -> DRChannel? {
        if let byId = availableChannels.first(where: { $0.id == identifier }) {
            return byId
        }
        return availableChannels.first {
            $0.slug.caseInsensitiveCompare(identifier) == .orderedSame
        }
    }

    // MARK: - Last Played Channel Management
    
    private func restoreLastPlayedChannel() {
        // Only restore if we have available channels and no current playback
        guard !availableChannels.isEmpty && playingChannel == nil else { return }
        
        // Find the last played channel in available channels
        if let lastPlayedChannel = userPreferences.findLastPlayedChannel(in: availableChannels) {
            // Only restore if it was played recently (within 24 hours)
            if userPreferences.isLastPlayedRecent(within: 24) {
                // Set the playing channel but don't start playback automatically
                // This will populate the mini player with the last played channel
                playingChannel = lastPlayedChannel
                
                // Get current program for the restored channel
                currentLiveProgram = getCurrentProgram(for: lastPlayedChannel)
                
                // Update Command Center with restored channel info
                audioPlayer.updateCommandCenterInfo(channel: lastPlayedChannel, program: currentLiveProgram, track: currentTrack)
            }
        }
    }
    
    func findLastPlayedChannel(in channels: [DRChannel]) -> DRChannel? {
        return userPreferences.findLastPlayedChannel(in: channels)
    }
    
    func getCurrentTrack(for channel: DRChannel) async -> DRTrack? {
        do {
            let indexPoints = try await networkService.fetchIndexPoints(for: channel.slug)

            return await MainActor.run {
                // Answered after a recording took over: it has no live track.
                guard self.onDemandEpisode == nil else { return nil }
                self.recentTracks = indexPoints.items
                let currentTrack = Self.heardTrack(in: indexPoints.items, at: self.listeningDate)
                self.currentTrack = currentTrack
                
                // Update Command Center with new track information
                let currentProgram = self.getCurrentProgram(for: channel)
                self.audioPlayer.updateCommandCenterInfo(channel: channel, program: currentProgram, track: currentTrack)
                return currentTrack
            }
        } catch {
            // Keep what is known only while it is still true. The last track used to stay
            // on screen however long ago it ended, for as long as the polls kept failing.
            reselectHeard()
            return nil
        }
    }
    
    
    
    private var trackPollingTask: Task<Void, Never>?
    
    /// Polls the live track for as long as `channel` is actually playing.
    ///
    /// This replaced a self-perpetuating chain — getCurrentTrack scheduled the next poll
    /// via DispatchQueue.asyncAfter, which called getCurrentTrack again. Nothing held a
    /// handle to the pending work, and its only guard was that `playingChannel` still
    /// matched. Since pausing leaves `playingChannel` set so the mini player keeps its
    /// content, pausing did not stop the chain: the app went on hitting
    /// /indexpoints/live every ~15s, foreground or background, until the channel changed
    /// or the app was killed.
    private func startPolling(for channel: DRChannel) {
        stopPolling()
        isPollingForTrack = true
        
        trackPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let track = await self.getCurrentTrack(for: channel)
                guard !Task.isCancelled else { return }
                
                // Wake just after the current track ends, otherwise fall back to the
                // fixed interval.
                let delay: TimeInterval
                let behind = await MainActor.run { self.secondsBehindLive }
                if let track, let endTime = track.endTime,
                   endTime.addingTimeInterval(behind) > Date() {
                    delay = max(endTime.timeIntervalSinceNow + behind + DRAPIConfig.trackUpdateBuffer, 1)
                } else {
                    delay = DRAPIConfig.trackPollingInterval
                }
                await MainActor.run {
                    self.nextLivePollingTime = Date().addingTimeInterval(delay)
                }
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
    
    /// Stops the track loop. Cancellation is real now: `Task.sleep` throws on cancel and the
    /// loop checks `Task.isCancelled`, so nothing is left in flight.
    private func stopPolling() {
        trackPollingTask?.cancel()
        trackPollingTask = nil
        isPollingForTrack = false
        nextLivePollingTime = nil
    }
    
    
    
    // MARK: - Sleep Timer

    /// The active sleep timer, if any.
    @Published private(set) var sleepTimer: SleepTimer?

    /// Seconds left, republished every tick so the UI can count down without owning a
    /// timer of its own.
    @Published private(set) var sleepTimerRemaining: TimeInterval = 0

    private var sleepTimerTask: Task<Void, Never>?

    /// Starts a sleep timer, replacing any existing one.
    ///
    /// Returns false when the mode cannot be satisfied — `.endOfProgramme` on a channel
    /// whose schedule the API did not give us, which is a real case rather than a
    /// theoretical one.
    @discardableResult
    func startSleepTimer(_ mode: SleepTimerMode) -> Bool {
        // A recording ends when what is left of it has played, not when it ended on air.
        let programmeEnd = onDemandEpisode != nil && onDemandDuration > 0
            ? Date().addingTimeInterval(max(onDemandDuration - onDemandPosition, 0))
            : playingChannel.flatMap { liveProgram(for: $0)?.endDate }
        guard let timer = SleepTimer(mode: mode, from: Date(), programmeEnd: programmeEnd) else {
            Log.playback.warning("sleep timer rejected: no end time for the current programme")
            return false
        }

        sleepTimer = timer
        sleepTimerRemaining = timer.remaining(at: Date())
        runSleepTimer(timer)
        return true
    }

    func cancelSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimer = nil
        sleepTimerRemaining = 0
        // Undo a fade that was already partway down.
        audioPlayer.setVolume(1)
    }

    /// Ticks once a second. The timer itself is a deadline, so this only reads the clock —
    /// a tick that arrives late, or not at all while suspended, cannot make it drift.
    private func runSleepTimer(_ timer: SleepTimer) {
        sleepTimerTask?.cancel()
        sleepTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let now = Date()

                self.sleepTimerRemaining = timer.remaining(at: now)
                self.audioPlayer.setVolume(timer.volumeMultiplier(at: now))

                if timer.hasFired(at: now) {
                    self.sleepTimerDidFire()
                    return
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func sleepTimerDidFire() {
        Log.playback.debug("sleep timer fired")

        if isPlaying {
            // The default pause() is the deliberate kind, which is right: this stop should
            // stand, not be undone by an interruption ending later.
            audioPlayer.pause()
            stopPolling()
            audioPlayer.updateCommandCenterPlaybackState()
        }

        // Restore the volume the fade took down, or the next play starts silent.
        audioPlayer.setVolume(1)

        sleepTimer = nil
        sleepTimerRemaining = 0
        sleepTimerTask = nil
    }


    // MARK: - Keeping the schedule current

    /// `/schedules/all/now` is the schedule, and it only carries what is on air at the
    /// moment it is asked. So it has to be asked again as programmes end — at first that
    /// happened only at launch, then every five minutes while playing, which left every
    /// card on Home showing what was on when the app opened.
    private var scheduleRefreshTask: Task<Void, Never>?

    /// Whether the app is in front. Refreshing is for someone looking or listening: in the
    /// background with nothing playing, there is no one to refresh for.
    ///
    /// In front means on either screen. With the phone locked in a cradle, the window is
    /// in the background while the car's screen lists what is on (F21).
    private var isAppActive: Bool { isWindowActive || isCarPlayConnected }
    private var isWindowActive = true
    private var isCarPlayConnected = false

    /// Past this, a refresh is due even if no programme has ended — DR changes its plans.
    private static let scheduleMaxAge: TimeInterval = 10 * 60
    /// After a programme's end, how long to give DR to move on to the next.
    private static let boundaryBuffer: TimeInterval = 5
    /// However the programmes fall, wake no sooner and no later than these.
    private static let refreshBounds: ClosedRange<TimeInterval> = 60...(10 * 60)

    /// Called by the app as its scene comes and goes.
    func setAppActive(_ active: Bool) {
        isWindowActive = active
        if active { becameActive() }
    }

    /// Called by the CarPlay scene as the car connects and disconnects (F21).
    func setCarPlayConnected(_ connected: Bool) {
        isCarPlayConnected = connected
        if connected { becameActive() }
    }

    private func becameActive() {
        refreshScheduleIfNeeded()
        refreshShowSchedule()
    }

    // MARK: - Favourite shows (F33)

    /// Fetches today's schedule for every channel not yet fetched this broadcast day, and
    /// folds it into the weekly template; then schedules reminders afresh from what is known
    /// (F51), whether or not anything needed fetching. Cheap to call: it fetches nothing when
    /// all is current. Returns the whole pass, for the background task to wait on.
    @discardableResult
    func refreshShowSchedule(inBackground: Bool = false,
                             favourites: FavouriteShows? = nil) -> Task<Void, Never> {
        let refresh = fetchDueShowSchedules(inBackground: inBackground, favourites: favourites)
        return Task { [weak self] in
            await refresh?.value
            await self?.rescheduleShowReminders().value
        }
    }

    private func fetchDueShowSchedules(inBackground: Bool,
                                       favourites: FavouriteShows?) -> Task<Void, Never>? {
        guard isOnline, !availableChannels.isEmpty else { return nil }
        return showSchedule.refreshIfDue(
            channels: availableChannels,
            favourites: favourites ?? userPreferences.favouriteShows,
            constrained: networkMonitor.isConstrained,
            inBackground: inBackground,
            fetchDay: { [weak self] channel in
                guard let self else { return [] }
                return try await self.fetchDaySchedule(for: channel)
            },
            onDay: { [weak self] day in self?.userPreferences.updateFavouriteShows(from: day) })
    }

    /// Replaces the pending show reminders with the coming week's (F51). `enabled` is the
    /// setting's new value while it is changing — @Published publishes before it changes.
    @discardableResult
    func rescheduleShowReminders(enabled: Bool? = nil) -> Task<Void, Never> {
        #if os(iOS) || os(macOS)
        #if DEBUG
        // UI tests never touch the simulator's real notifications.
        if UITestFixtures.isActive { return Task {} }
        #endif
        let enabled = enabled ?? userPreferences.remindsShows
        let plan = enabled ? showSchedule.reminderPlan(for: userPreferences.favouriteShows) : []
        let titles = Dictionary(availableChannels.map { ($0.slug, $0.qualifiedName) },
                                uniquingKeysWith: { first, _ in first })
        let reminders = showReminders
        return Task {
            await reminders.reschedule(plan, enabled: enabled) { slug in
                titles[slug] ?? slug.uppercased()
            }
        }
        #else
        return Task {}
        #endif
    }

    /// The catalogue's channel for `slug`: the template stores slugs, and the catalogue's
    /// copy carries what the channel directory knows.
    func channel(forSlug slug: String) -> DRChannel? {
        availableChannels.first { $0.slug == slug }
    }

    /// Whether to fetch the schedule again: never fetched, fetched too long ago, or a
    /// programme in it has ended.
    static func needsScheduleRefresh(_ programmes: [DREpisode], lastFetched: Date?,
                                     now: Date) -> Bool {
        guard let lastFetched, now.timeIntervalSince(lastFetched) < scheduleMaxAge else {
            return true
        }
        return hasEnded(programmes, at: now)
    }

    static func hasEnded(_ programmes: [DREpisode], at now: Date) -> Bool {
        programmes.contains { ($0.endDate ?? .distantFuture) <= now }
    }

    /// How long until the next refresh: just after the soonest programme still on air ends.
    static func scheduleRefreshDelay(_ programmes: [DREpisode], now: Date) -> TimeInterval {
        let nextEnd = programmes.compactMap(\.endDate).filter { $0 > now }.min()
        let delay = nextEnd.map { $0.timeIntervalSince(now) + boundaryBuffer }
            ?? refreshBounds.upperBound
        return min(max(delay, refreshBounds.lowerBound), refreshBounds.upperBound)
    }

    private func startScheduleRefresh() {
        scheduleRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                // Read without holding self across the sleep.
                guard let delay = self.map({ Self.scheduleRefreshDelay($0.cachedSchedules,
                                                                       now: Date()) })
                else { return }
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, let self else { return }
                self.refreshScheduleIfNeeded()
            }
        }
    }

    private func refreshScheduleIfNeeded() {
        let now = Date()
        // A programme that ended is no longer drawn as on air, whether or not a fetch
        // follows — offline, none will. The views ask on every render; this is what
        // makes them render.
        if Self.hasEnded(cachedSchedules, at: now) {
            objectWillChange.send()
            refreshCurrentProgram()
        }
        guard isAppActive || audioPlayer.wantsPlayback, isOnline,
              Self.needsScheduleRefresh(cachedSchedules, lastFetched: lastSchedulesUpdate,
                                        now: now)
        else { return }
        startCatalogueFetch()
    }

    // MARK: - Program Refresh
    
    func refreshCurrentProgram() {
        guard let playingChannel = playingChannel else { return }
        
        let newProgram = getCurrentProgram(for: playingChannel)
        
        // Only update if the program has changed
        if newProgram?.id != currentLiveProgram?.id {
            Task { @MainActor in
                self.currentLiveProgram = newProgram
                
                // Update Command Center with new program information
                self.audioPlayer.updateCommandCenterInfo(channel: playingChannel, program: newProgram, track: self.currentTrack)
            }
        }
    }
    
    // MARK: - New Live Polling System
    
    // MARK: - Image Preloading
    
    /// Warms the artwork the channel lists show. Only the primary image per episode, at
    /// thumbnail size, four downloads at a time — see `preloadPrimaryImages`.
    private func preloadChannelImages(from schedules: [DREpisode]) async {
        // Show Images off is a request for less data; fetching every picture anyway would
        // spend it on images nothing draws.
        guard userPreferences.showsArtwork else { return }
        imageCache.preloadPrimaryImages(from: schedules)
    }
    
    /// Returns image cache statistics
    func getImageCacheStatistics() -> (memoryCount: Int, diskSize: Int64) {
        return imageCache.getCacheStatistics()
    }
    
    /// Clears all cached images
    func clearImageCache() {
        imageCache.clearAllCaches()
    }
}
