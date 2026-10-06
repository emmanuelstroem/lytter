//
//  ListeningSurfaces.swift
//  lytter
//

#if os(iOS)
import Combine
import Foundation
import UIKit
import WidgetKit
import os

/// Keeps the widgets and the Control Centre control in step with what is playing (F18).
///
/// They live in another process and cannot see the player, so the app tells them: on every
/// change of station, programme or play/pause it writes a `NowPlayingSnapshot` into the app
/// group and asks WidgetKit to redraw. Redraws asked for while the app has an active audio
/// session do not count against WidgetKit's budget.
///
/// The extension never fetches. For "what's next" this asks DR for the playing channel's
/// schedule snapshot once per programme, the request the schedule sheets already make.
final class ListeningSurfaces {
    private let store: NowPlayingStore
    private weak var manager: DRServiceManager?
    private var cancellables = Set<AnyCancellable>()

    /// The last snapshot written, to skip writes that would say nothing new.
    private var written: NowPlayingSnapshot?
    /// The last favourites written, for the same reason.
    private var writtenFavourites: FavouriteStations?
    /// Where the saved artwork came from; nil when none is saved.
    private var artworkSource: String?

    /// The playing channel's schedule snapshot, and which programme it was fetched for.
    private var upcoming: (channelID: String, programmeID: String, episodes: [DREpisode])?
    private var upcomingTask: Task<Void, Never>?

    init(store: NowPlayingStore = NowPlayingStore()) {
        self.store = store
        written = store.load()
        writtenFavourites = store.loadFavourites()
        // Whatever an earlier launch saved, of a source not known any more. Recorded so
        // that Show Images, off since, still removes it.
        artworkSource = store.artworkData() == nil ? nil : "saved earlier"
    }

    /// Starts following `manager`.
    func start(observing manager: DRServiceManager) {
        self.manager = manager
        let preferences = manager.userPreferences
        // @Published publishes before the property changes, so the values themselves are
        // not used: the debounce lets every change of one moment land, and `publish` reads
        // them from the manager afterwards.
        Publishers.CombineLatest3(manager.$playingChannel.map { $0?.id },
                                  manager.$currentLiveProgram.map { $0?.id },
                                  manager.$isPlaying)
            .map { _ in () }
            .merge(with: preferences.$showsArtwork.map { _ in () })
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] in self?.publish() }
            .store(in: &cancellables)

        // The channels, for a favourite DR has retired or renamed.
        preferences.$favourites.map { _ in () }
            .merge(with: manager.$availableChannels.map { _ in () })
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] in self?.publishFavourites() }
            .store(in: &cancellables)
    }

    private func publishFavourites() {
        guard let manager else { return }
        let favourites = FavouriteStations.make(favourites: manager.userPreferences.favourites,
                                                channels: manager.availableChannels)
        guard favourites != writtenFavourites else { return }
        store.saveFavourites(favourites)
        writtenFavourites = favourites
        WidgetCenter.shared.reloadTimelines(ofKind: NowPlayingStore.favouritesKind)
    }

    // MARK: - Publishing

    private func publish() {
        guard let manager else { return }
        let snapshot = currentSnapshot(from: manager)
        if !(snapshot?.says(theSameAs: written) ?? (written == nil)) {
            if let snapshot { store.save(snapshot) } else { store.clear() }
            let playingChanged = snapshot?.isPlaying != written?.isPlaying
                || snapshot?.channelID != written?.channelID
            written = snapshot
            reloadWidgets(controls: playingChanged)
        }
        updateArtwork(for: manager)
    }

    /// What to write now. With nothing in the player — stopped, or nothing played lately —
    /// the last station is kept, paused, so the widget's button has something to resume.
    private func currentSnapshot(from manager: DRServiceManager) -> NowPlayingSnapshot? {
        guard let channel = manager.playingChannel else { return written?.paused(at: Date()) }
        let isOnDemand = manager.onDemandEpisode != nil
        let programme = manager.getCurrentProgram(for: channel)
        // Asked for with no programme too: started at a boundary, before the catalogue has
        // moved on, the schedule is what says what is on now.
        if manager.isPlaying, !isOnDemand {
            loadUpcoming(for: channel, after: programme)
        }
        let episodes = upcoming.flatMap { $0.channelID == channel.id ? $0.episodes : nil } ?? []
        return NowPlayingSnapshot.make(channel: channel, programme: programme,
                                       upcoming: episodes,
                                       isPlaying: manager.isPlaying, isOnDemand: isOnDemand,
                                       secondsBehindLive: manager.secondsBehindLive,
                                       now: Date())
    }

    /// `controls` when the station or play/pause changed: the control's icon says which,
    /// and the Favourites widget marks the station playing.
    private func reloadWidgets(controls: Bool) {
        WidgetCenter.shared.reloadTimelines(ofKind: NowPlayingStore.widgetKind)
        guard controls else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: NowPlayingStore.favouritesKind)
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadControls(ofKind: NowPlayingStore.controlKind)
        }
    }

    /// Fetches what follows `programme` on `channel`, once for each programme — and once
    /// while there is none: a failure is not retried until the next one, and the widget
    /// meanwhile shows no "next".
    private func loadUpcoming(for channel: DRChannel, after programme: DREpisode?) {
        let programmeID = programme?.id ?? ""
        if let upcoming, upcoming.channelID == channel.id, upcoming.programmeID == programmeID {
            return
        }
        upcomingTask?.cancel()
        // The last fetch's programmes stand in until this one answers; those not after the
        // new programme are dropped when the snapshot is made.
        let kept = upcoming?.channelID == channel.id ? upcoming?.episodes ?? [] : []
        upcoming = (channel.id, programmeID, kept)
        upcomingTask = Task { [weak self] in
            guard let manager = self?.manager else { return }
            let episodes = await manager.loadSchedule(for: channel)
            guard !Task.isCancelled, let self, !episodes.isEmpty,
                  self.upcoming?.channelID == channel.id,
                  self.upcoming?.programmeID == programmeID else { return }
            self.upcoming = (channel.id, programmeID, episodes)
            self.publish()
        }
    }

    // MARK: - Artwork

    /// Saves the playing programme's artwork beside the snapshot, at a size widgets can
    /// draw, from the image cache the lock screen already filled. None with Show Images off.
    private func updateArtwork(for manager: DRServiceManager) {
        // Stopped, the paused snapshot keeps its station, and so its picture.
        let source: String? = !manager.userPreferences.showsArtwork ? nil
            : manager.playingChannel.map { manager.artworkURL(for: $0)?.absoluteString }
                ?? artworkSource
        guard source != artworkSource else { return }
        artworkSource = source
        guard let source else {
            store.saveArtwork(nil)
            reloadWidgets(controls: false)
            return
        }
        ImageCacheService.shared.loadImage(from: source, maxPixelSize: Self.artworkPixels) { [weak self] image in
            guard let self, self.artworkSource == source else { return }
            self.store.saveArtwork(image?.jpegData(compressionQuality: 0.8))
            self.reloadWidgets(controls: false)
        }
    }

    /// The longest edge of the saved artwork. A large widget's picture is about 170 points,
    /// so this covers it at 2x; WidgetKit refuses images much larger than a widget's area.
    static let artworkPixels: CGFloat = 360

    // MARK: - Play/pause from outside the app

    /// What `PlayFavouriteIntent` does: the station playing pauses, any other plays.
    @MainActor
    static func playFavourite(_ channelID: String) async {
        let manager = DRServiceManager.shared
        if let playing = manager.playingChannel, playing.id == channelID {
            manager.togglePlayback(for: playing)
            return
        }
        let channels = await StationCatalogue.channels()
        guard let channel = channels.first(where: { $0.id == channelID }) else {
            Log.playback.warning("a favourite from the widget is not in the catalogue")
            return
        }
        manager.playChannel(channel)
    }

    /// What `ToggleListeningIntent` does: pause what is playing, or play the station in the
    /// player — failing that, the last one played.
    @MainActor
    static func toggleListening() async {
        let manager = DRServiceManager.shared
        if let channel = manager.playingChannel {
            manager.togglePlayback(for: channel)
            return
        }
        let channels = await StationCatalogue.channels()
        if let channel = manager.userPreferences.findLastPlayedChannel(in: channels) {
            manager.playChannel(channel)
        }
    }
}
#endif
