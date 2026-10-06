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
        let sections = Broadcaster.sections(from: [channel("p1"), channel("p3")])

        #expect(sections.count == 1)
        #expect(sections.first?.broadcaster == .dr)
        #expect(sections.first?.channels.map(\.id) == ["p1", "p3"])
    }

    /// A broadcaster that supplies nothing is left out rather than rendered as an empty
    /// heading — which is what happens when one source fails to load and others succeed.
    @Test func aBroadcasterWithNoChannelsIsOmitted() {
        #expect(Broadcaster.sections(from: []).isEmpty)
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

    @Test func twoBroadcastersBecomeTwoSectionsInDisplayOrder() {
        let channels = [channel("n1", broadcasterID: "nova"), channel("p1"), channel("n2", broadcasterID: "nova")]
        let sections = Broadcaster.sections(from: channels, registered: [nova, .dr])

        #expect(sections.map(\.broadcaster) == [.dr, nova])
        #expect(sections.last?.channels.map(\.id) == ["n1", "n2"])
    }

    @Test func drIsRegistered() {
        #expect(BroadcasterRegistry.makeSources().contains { $0 is DRSource })
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
