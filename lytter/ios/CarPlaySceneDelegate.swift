//
//  CarPlaySceneDelegate.swift
//  lytter
//

#if os(iOS)
import CarPlay
import Combine
import UIKit
import os

/// The app on the car's screen (F21): two tabs of stations, and the system's Now Playing.
///
/// Declared in Info.plist for the CarPlay role only; the phone's window stays SwiftUI's.
/// Everything shown is worked out by `CarPlayCatalogue`, which is tested; this turns it
/// into templates and hands taps back to the same `DRServiceManager` the phone uses, so
/// what plays in the car is what the phone's mini player shows.
///
/// Now Playing needs nothing of its own. `CPNowPlayingTemplate` draws from the now-playing
/// info and remote commands `AudioPlayerService` already publishes for the lock screen.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private let manager = DRServiceManager.shared
    private var preferences: UserPreferencesService { manager.userPreferences }

    private var interfaceController: CPInterfaceController?
    private let homeTemplate = CPListTemplate(title: String(localized: "Home"), sections: [])
    private let stationsTemplate = CPListTemplate(title: String(localized: "Stations"), sections: [])
    /// The districts list, while one is open, and the station it lists.
    private var districtList: (template: CPListTemplate, stationID: String)?

    private var subscriptions = Set<AnyCancellable>()
    /// Asks for a redraw that the managers' publishers would not: artwork that has arrived.
    private let redraw = PassthroughSubject<Void, Never>()
    /// What was last drawn. The manager publishes every second while a recording plays,
    /// and rebuilding the car's lists that often for nothing is wasted work on its screen.
    private var drawn: CarPlayCatalogue?
    private var drawnDistricts: [CarPlayCatalogue.Row]?

    private var images: [String: UIImage] = [:]
    private var loadingImages = Set<String>()

    // MARK: - Scene

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        Log.carPlay.info("connected")
        self.interfaceController = interfaceController

        homeTemplate.tabImage = UIImage(systemName: "house.fill")
        stationsTemplate.tabImage = UIImage(systemName: "dot.radiowaves.left.and.right")
        homeTemplate.emptyViewTitleVariants = [String(localized: "Nothing here yet")]
        homeTemplate.emptyViewSubtitleVariants = [
            String(localized: "Your favourites and the stations you play appear here."),
        ]
        let nowPlaying = CPNowPlayingTemplate.shared
        nowPlaying.isUpNextButtonEnabled = false
        nowPlaying.isAlbumArtistButtonEnabled = false

        let tabs = CPTabBarTemplate(templates: [homeTemplate, stationsTemplate])
        interfaceController.setRootTemplate(tabs, animated: false, completion: nil)

        manager.setCarPlayConnected(true)
        if manager.availableChannels.isEmpty && !manager.isLoading {
            manager.loadChannels()
        }
        observe()
        draw(force: true)
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        Log.carPlay.info("disconnected")
        subscriptions.removeAll()
        self.interfaceController = nil
        districtList = nil
        drawn = nil
        drawnDistricts = nil
        manager.setCarPlayConnected(false)
    }

    /// Redraws whenever the catalogue, playback or the listener's lists change — observing
    /// the preferences directly, since they do not republish through the manager.
    private func observe() {
        manager.objectWillChange
            .merge(with: preferences.objectWillChange, redraw)
            // `objectWillChange` fires before the change; drawing a moment later reads the
            // new values, and folds a burst of changes into one redraw.
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] in self?.draw() }
            .store(in: &subscriptions)
    }

    // MARK: - Drawing

    private var context: CarPlayCatalogue.Context {
        let manager = manager
        let showsArtwork = preferences.showsArtwork
        return CarPlayCatalogue.Context(
            region: preferences.preferredDistrict,
            audibleChannelID: manager.isPlaying ? manager.playingChannel?.id : nil,
            programme: { manager.getCurrentProgram(for: $0)?.cleanTitle() },
            artwork: { showsArtwork ? manager.artworkURL(for: $0)?.absoluteString : nil })
    }

    private func draw(force: Bool = false) {
        guard interfaceController != nil else { return }
        let context = context
        let catalogue = CarPlayCatalogue(
            channels: manager.availableChannels,
            favourites: preferences.favourites,
            recentlyPlayed: preferences.recentlyPlayed,
            context: context,
            titles: (String(localized: "Favourites"), String(localized: "Recently Played")))

        if force || catalogue != drawn {
            drawn = catalogue
            let home = CarPlayCatalogue.capped(catalogue.home,
                                               items: CPListTemplate.maximumItemCount,
                                               sections: CPListTemplate.maximumSectionCount)
            homeTemplate.updateSections(home.map {
                CPListSection(items: $0.rows.map(item(for:)), header: $0.title,
                              sectionIndexTitle: nil)
            })
            let stations = CarPlayCatalogue.capped([.init(title: "", rows: catalogue.stations)],
                                                   items: CPListTemplate.maximumItemCount,
                                                   sections: 1)
            stationsTemplate.updateSections(stations.map {
                CPListSection(items: $0.rows.map(item(for:)))
            })
            describeEmptyStations()
        }

        drawDistricts(force: force)
    }

    private func drawDistricts(force: Bool) {
        guard let (template, stationID) = districtList else { return }
        // Popped: nothing to keep up to date.
        guard interfaceController?.templates.contains(template) == true else {
            districtList = nil
            drawnDistricts = nil
            return
        }
        let rows = CarPlayCatalogue.districts(of: stationID, in: manager.availableChannels,
                                              context: context) ?? []
        guard force || rows != drawnDistricts else { return }
        drawnDistricts = rows
        template.updateSections([CPListSection(items: rows.map(item(for:)))])
    }

    /// What the Stations tab says while it has none: the phone's words for the same state.
    private func describeEmptyStations() {
        switch CatalogueState.current(hasChannels: !manager.availableChannels.isEmpty,
                                      isLoading: manager.isLoading,
                                      isWaitingLong: manager.isWaitingLong,
                                      problem: manager.connectionProblem) {
        case .content:
            stationsTemplate.emptyViewTitleVariants = []
            stationsTemplate.emptyViewSubtitleVariants = []
        case .loading(let isSlow):
            stationsTemplate.emptyViewTitleVariants = [
                isSlow ? String(localized: "Still waiting for DR…") : String(localized: "Loading channels..."),
            ]
            stationsTemplate.emptyViewSubtitleVariants = []
        case .problem(let problem):
            stationsTemplate.emptyViewTitleVariants = [problem.title]
            stationsTemplate.emptyViewSubtitleVariants = [problem.message(hasContent: false)]
        case .empty:
            stationsTemplate.emptyViewTitleVariants = [String(localized: "No channels available")]
            stationsTemplate.emptyViewSubtitleVariants = []
        }
    }

    private func item(for row: CarPlayCatalogue.Row) -> CPListItem {
        let item = CPListItem(text: row.title, detailText: row.detail,
                              image: image(for: row.imageURL))
        item.isPlaying = row.isPlaying
        item.playingIndicatorLocation = .trailing
        if case .chooseDistrict = row.action {
            item.accessoryType = .disclosureIndicator
        }
        item.handler = { [weak self] _, completion in
            self?.select(row)
            completion()
        }
        return item
    }

    // MARK: - Selection

    private func select(_ row: CarPlayCatalogue.Row) {
        switch row.action {
        case .play(let channel):
            // Choosing what is already on carries on with it; see `selectionAction`.
            manager.playChannel(channel)
            showNowPlaying()
        case .chooseDistrict(let stationID):
            openDistricts(of: stationID, titled: row.title)
        }
    }

    private func openDistricts(of stationID: String, titled title: String) {
        guard let interfaceController else { return }
        let template = CPListTemplate(title: title, sections: [])
        districtList = (template, stationID)
        interfaceController.pushTemplate(template, animated: true, completion: nil)
        drawDistricts(force: true)
    }

    /// What the system's own audio apps do on a play: show what is playing. Not pushed
    /// twice, which would leave two Now Playing screens to go back through.
    private func showNowPlaying() {
        guard let interfaceController,
              !(interfaceController.topTemplate is CPNowPlayingTemplate) else { return }
        interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: true,
                                         completion: nil)
    }

    // MARK: - Artwork

    private static let placeholder = UIImage(systemName: "dot.radiowaves.left.and.right")

    /// The artwork if it has been loaded, and otherwise the placeholder while it loads; the
    /// list is redrawn once it arrives.
    private func image(for url: String?) -> UIImage? {
        guard let url else { return Self.placeholder }
        if let image = images[url] { return image }
        load(url)
        return Self.placeholder
    }

    private func load(_ url: String) {
        guard loadingImages.insert(url).inserted else { return }
        let size = CPListItem.maximumImageSize
        let scale = interfaceController?.carTraitCollection.displayScale ?? 2
        Task { [weak self] in
            let image = await ImageCacheService.shared.image(
                for: url, maxPixelSize: max(size.width, size.height) * scale)
            guard let self else { return }
            self.loadingImages.remove(url)
            guard let image else { return }
            self.images[url] = image
            self.drawn = nil
            self.drawnDistricts = nil
            self.redraw.send()
        }
    }
}
#endif
