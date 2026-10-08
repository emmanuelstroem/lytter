//
//  BroadcasterTests.swift
//  lytterTests
//

import Foundation
import Testing
@testable import lytter

/// The home screen is meant to read as one section per broadcaster. While DR is the only
/// source that is indistinguishable from a section called "DR" — these pin the difference,
/// so the grouping is already correct when a second source arrives.
///
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct BroadcasterTests {

    private func channel(_ id: String, broadcasterID: String? = nil) -> DRChannel {
        DRChannel(id: id, title: id.uppercased(), slug: id, type: "Channel", presentationUrl: nil,
                  broadcasterID: broadcasterID)
    }

    /// A second broadcaster, for what only shows once there are two.
    private let nova = Broadcaster(id: "nova", name: "Nova", displayOrder: 1)

    @Test func everyChannelBelongsToABroadcaster() {
        #expect(Broadcaster.supplying(channel("p1")) == .dr)
    }

    @Test func channelsBecomeOneSectionPerBroadcaster() {
        let sections = Broadcaster.sections(from: [channel("p1"), channel("p3")], shown: [.dr])

        #expect(sections.count == 1)
        #expect(sections.first?.broadcaster == .dr)
        #expect(sections.first?.channels.map(\.id) == ["p1", "p3"])
    }

    /// A broadcaster that supplies nothing is left out rather than rendered as an empty
    /// heading — which is what happens when one source fails to load and others succeed.
    @Test func aBroadcasterWithNoChannelsIsOmitted() {
        #expect(Broadcaster.sections(from: [], shown: [.dr]).isEmpty)
    }

    /// Explicit ordering, not alphabetical: the national broadcaster belongs at the top
    /// whatever it happens to be called.
    @Test func sectionsFollowDisplayOrder() {
        let registered = BroadcasterRegistry.broadcasters
        let ordered = registered.sorted { $0.displayOrder < $1.displayOrder }

        #expect(ordered.first == .dr)
        #expect(Set(registered.map(\.id)).count == registered.count,
                "two broadcasters sharing an id would collapse into one section")
    }

    /// DR's JSON carries no broadcaster, and nor does a channel cached before there was a
    /// second one. Both have to stay DR's, or every favourite would lose its station.
    @Test func aChannelThatNamesNoBroadcasterIsDRs() throws {
        let cached = Data(#"{"id":"urn:dr:radio:channel:1","title":"P1","slug":"p1","type":"Channel"}"#.utf8)
        let decoded = try JSONDecoder().decode(DRChannel.self, from: cached)

        #expect(decoded.broadcasterID == nil)
        #expect(Broadcaster.supplying(decoded) == .dr)
    }

    @Test func aChannelBelongsToTheBroadcasterItNames() {
        let registered: [Broadcaster] = [.dr, nova]

        #expect(Broadcaster.supplying(channel("n1", broadcasterID: "nova"), in: registered) == nova)
    }

    /// The broadcaster survives the disk cache, so a relaunch does not file another
    /// broadcaster's channels under DR.
    @Test func theBroadcasterIsKeptThroughTheCache() throws {
        let encoded = try JSONEncoder().encode(channel("n1", broadcasterID: "nova"))

        #expect(try JSONDecoder().decode(DRChannel.self, from: encoded).broadcasterID == "nova")
    }

    @Test func twoBroadcastersBecomeTwoSectionsInTheOrderShown() {
        let channels = [channel("n1", broadcasterID: "nova"), channel("p1"), channel("n2", broadcasterID: "nova")]
        let sections = Broadcaster.sections(from: channels, shown: [.dr, nova], registered: [nova, .dr])

        #expect(sections.map(\.broadcaster) == [.dr, nova])
        #expect(sections.last?.channels.map(\.id) == ["n1", "n2"])
        #expect(Broadcaster.sections(from: channels, shown: [nova, .dr], registered: [nova, .dr])
                    .map(\.broadcaster) == [nova, .dr], "the listener's order is not followed")
    }

    /// A hidden broadcaster has no section, even with its channels still in hand — an
    /// answer that was on its way when it was hidden.
    @Test func aHiddenBroadcasterHasNoSection() {
        let channels = [channel("p1"), channel("n1", broadcasterID: "nova")]
        let sections = Broadcaster.sections(from: channels, shown: [.dr], registered: [.dr, nova])

        #expect(sections.map(\.broadcaster) == [.dr])
    }

    @Test func drIsRegistered() {
        #expect(BroadcasterRegistry.makeSources().contains { $0 is DRSource })
    }

    /// The UI tests' second broadcaster is theirs alone: without it, Settings would grow a
    /// Broadcasters section for everyone.
    @Test func theFixtureBroadcasterIsNotRegisteredOutsideUITests() {
        #expect(!BroadcasterRegistry.makeSources().contains { $0 is FixtureSource })
    }

    @Test func sectionIdentityIsTheBroadcaster() {
        let section = BroadcasterSection(broadcaster: .dr, channels: [channel("p1")])

        #expect(section.id == "dr")
    }
}


/// The catalogue is fetched from every source at once (F54).
@MainActor
struct CatalogueTests {

    private struct Down: Error, Equatable { let source: String }

    private func onAir(_ slug: String) -> DREpisode {
        ShowTestSupport.airing(nil, on: slug, at: "2026-10-05 07:05")
    }

    /// One broadcaster being down must not take the others with it.
    @Test func aFailingSourceLeavesTheOthers() throws {
        let merged = try Catalogue.merge([.failure(Down(source: "dr")), .success([onAir("nova")])])

        #expect(merged.map(\.channel.slug) == ["nova"])
    }

    /// Only when nothing answers is it a failure — and it is the first source's, which is
    /// DR's, because that is what the connection banner explains.
    @Test func everySourceFailingIsAFailureOfTheFirst() {
        #expect(throws: Down(source: "dr")) {
            try Catalogue.merge([.failure(Down(source: "dr")), .failure(Down(source: "nova"))])
        }
    }

    @Test func everySourceIsKeptInOrder() throws {
        let merged = try Catalogue.merge([.success([onAir("p1"), onAir("p3")]), .success([onAir("nova")])])

        #expect(merged.map(\.channel.slug) == ["p1", "p3", "nova"])
    }

    @Test func fetchingAsksEverySource() async throws {
        let episodes = try await Catalogue.fetch(from: [FixedSource(), FailingSource(), FixedSource()])

        #expect(episodes.map(\.channel.slug) == ["fixed", "fixed"])
    }
}

@MainActor
private final class FixedSource: BroadcasterSource {
    static let broadcaster = Broadcaster(id: "fixed", name: "Fixed", displayOrder: 1)
    init() {}
    func fetchCatalogue() async throws -> [DREpisode] {
        [ShowTestSupport.airing(nil, on: "fixed", at: "2026-10-05 07:05")]
    }
}

@MainActor
private final class FailingSource: BroadcasterSource {
    static let broadcaster = Broadcaster(id: "failing", name: "Failing", displayOrder: 2)
    init() {}
    func fetchCatalogue() async throws -> [DREpisode] { throw URLError(.cannotConnectToHost) }
}


/// Which broadcasters are shown, and in what order (F54b).
@MainActor
struct VisibleBroadcastersTests {

    private let nova = Broadcaster(id: "nova", name: "Nova", displayOrder: 1)
    private let pop = Broadcaster(id: "pop", name: "PopFM", displayOrder: 2)
    private var registered: [Broadcaster] { [pop, .dr, nova] }

    /// Before anything has been moved, display order: DR first.
    @Test func withNothingSavedTheOrderIsDisplayOrder() {
        #expect(Broadcaster.visible(registered: registered, order: [], hidden: []) == [.dr, nova, pop])
    }

    /// An order that is neither the registry's nor display order, so following either by
    /// mistake shows.
    @Test func theSavedOrderIsFollowed() {
        #expect(Broadcaster.visible(registered: registered, order: ["nova", "pop", "dr"], hidden: [])
                    == [nova, pop, .dr])
    }

    /// A broadcaster registered after the order was saved is not lost: it follows the
    /// saved ones, by display order.
    @Test func aNewlyRegisteredBroadcasterFollowsTheSavedOnes() {
        #expect(Broadcaster.visible(registered: registered, order: ["nova", "dr"], hidden: [])
                    == [nova, .dr, pop])
    }

    /// One removed from the app since is passed over, as is a duplicate.
    @Test func idsNoLongerRegisteredAreIgnored() {
        #expect(Broadcaster.arranged(registered, order: ["gone", "nova", "nova", "dr"])
                    == [nova, .dr, pop])
    }

    @Test func hiddenBroadcastersAreLeftOut() {
        #expect(Broadcaster.visible(registered: registered, order: [], hidden: ["nova"]) == [.dr, pop])
    }

    /// Settings lists the hidden ones too, or one could never be switched back on.
    @Test func settingsListsHiddenBroadcasters() {
        #expect(Broadcaster.arranged(registered, order: []) == [.dr, nova, pop])
    }

    /// Never an empty app: with every broadcaster hidden, the first in order is shown.
    @Test func theLastBroadcasterIsNeverHidden() {
        #expect(Broadcaster.visible(registered: registered, order: ["nova"], hidden: ["dr", "nova", "pop"])
                    == [nova])
    }

    /// With DR alone, the preferences will not hide it.
    @Test func preferencesRefuseToHideTheLastBroadcaster() {
        let preferences = UserPreferencesService()
        preferences.setBroadcaster(Broadcaster.dr.id, shown: false)

        #expect(preferences.visibleBroadcasters == [.dr])
        #expect(!preferences.hiddenBroadcasterIDs.contains(Broadcaster.dr.id))
    }

    // MARK: Switching one on or off in Settings

    @Test func switchingOneOffHidesIt() {
        #expect(Broadcaster.hidden(afterSwitching: "nova", on: false, registered: registered,
                                   order: [], hidden: []) == ["nova"])
    }

    @Test func switchingOneOnShowsIt() {
        #expect(Broadcaster.hidden(afterSwitching: "nova", on: true, registered: registered,
                                   order: [], hidden: ["nova", "pop"]) == ["pop"])
    }

    @Test func switchingOffTheLastOneShownChangesNothing() {
        #expect(Broadcaster.hidden(afterSwitching: "dr", on: false, registered: registered,
                                   order: [], hidden: ["nova", "pop"]) == ["nova", "pop"])
    }

    /// With every one stored as hidden, the first is shown anyway. Switching another on
    /// must not take that one away: what is on screen stays on screen.
    @Test func switchingAnotherOnKeepsTheOneShownAnyway() {
        let hidden = Broadcaster.hidden(afterSwitching: "nova", on: true, registered: registered,
                                        order: [], hidden: ["dr", "nova", "pop"])

        #expect(hidden == ["pop"])
        #expect(Broadcaster.visible(registered: registered, order: [], hidden: hidden) == [.dr, nova])
    }

    /// A switch reads what is on screen, not what is stored.
    @Test func theOneShownAnywayReadsOn() {
        let preferences = UserPreferencesService()

        #expect(preferences.isShown(Broadcaster.dr.id))
        #expect(!preferences.isShown("not-registered"))
    }
}


/// Home's chips: which are offered, and which Home opens on (F54c).
@MainActor
struct HomeScopeTests {

    private let nova = Broadcaster(id: "nova", name: "Nova", displayOrder: 1)

    /// DR has a chip while it is the only broadcaster too, so the row does not change
    /// shape when a second one arrives.
    @Test func oneBroadcasterHasAChipOfItsOwn() {
        #expect(HomeScope.available(visible: [.dr]) == [.forYou, .all, .broadcaster("dr")])
    }

    /// Two or more: one chip each, in the order shown — the listener's, not the registry's.
    @Test func twoBroadcastersHaveAChipEach() {
        #expect(HomeScope.available(visible: [nova, .dr])
                    == [.forYou, .all, .broadcaster("nova"), .broadcaster("dr")])
    }

    /// A first launch opens on stations, not on an empty page of favourites.
    @Test func withNothingOfTheirOwnHomeOpensOnAll() {
        #expect(HomeScope.initial(stored: "", available: [.forYou, .all], hasOwnStations: false) == .all)
    }

    @Test func withFavouritesOrHistoryHomeOpensForYou() {
        #expect(HomeScope.initial(stored: "", available: [.forYou, .all], hasOwnStations: true) == .forYou)
    }

    /// The chip last chosen wins over the default, either way round.
    @Test func theLastChoiceIsKept() {
        let available = HomeScope.available(visible: [.dr, nova])

        #expect(HomeScope.initial(stored: "all", available: available, hasOwnStations: true) == .all)
        #expect(HomeScope.initial(stored: "forYou", available: available, hasOwnStations: true) == .forYou)
        #expect(HomeScope.initial(stored: "broadcaster:nova", available: available, hasOwnStations: true)
                    == .broadcaster("nova"))
    }

    /// For you chosen last time, but empty now, opens on All rather than on an empty page.
    @Test func anEmptyForYouOpensOnAllEvenWhenItWasChosen() {
        let available = HomeScope.available(visible: [.dr])

        #expect(HomeScope.initial(stored: "forYou", available: available, hasOwnStations: false) == .all)
    }

    /// A broadcaster hidden since it was chosen leaves Home on All, where its stations
    /// were — not on For you, which never showed them.
    @Test func aHiddenBroadcasterFallsBackToAll() {
        let available = HomeScope.available(visible: [.dr])

        #expect(HomeScope.initial(stored: "broadcaster:nova", available: available, hasOwnStations: true) == .all)
        #expect(HomeScope.resolved(.broadcaster("nova"), in: available) == .all)
        #expect(HomeScope.resolved(.forYou, in: available) == .forYou)
    }

    /// Something stored that is not a scope at all is as good as nothing stored.
    @Test func anUnreadableChoiceIsIgnored() {
        #expect(HomeScope.initial(stored: "radio", available: [.forYou, .all], hasOwnStations: true) == .forYou)
        #expect(HomeScope(storageValue: "broadcaster:") == nil)
    }

    @Test func everyScopeSurvivesStorage() {
        for scope in [HomeScope.forYou, .all, .broadcaster("dr"), .broadcaster("urn:lytter:nova")] {
            #expect(HomeScope(storageValue: scope.storageValue) == scope)
        }
    }
}
