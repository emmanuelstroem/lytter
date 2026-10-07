//
//  BroadcasterRegistry.swift
//  lytter
//

import Foundation

/// Every broadcaster the app can play.
///
/// **Adding a broadcaster:** a folder under `broadcasters/` with a `BroadcasterSource` in
/// it, and that source's type in `sourceTypes`.
/// **Removing one:** delete both. The folder has to go too — the target compiles every
/// file in it whether or not anything refers to it.
///
/// The order here is the order sources are asked in, not the order they are shown in;
/// that is `Broadcaster.displayOrder`.
enum BroadcasterRegistry {

    static let sourceTypes: [any BroadcasterSource.Type] = [
        DRSource.self,
    ] + testSourceTypes

    /// A second broadcaster, when a UI test asks for one. See `FixtureSource`.
    private static var testSourceTypes: [any BroadcasterSource.Type] {
        #if DEBUG
        UITestFixtures.hasSecondBroadcaster ? [FixtureSource.self] : []
        #else
        []
        #endif
    }

    static var broadcasters: [Broadcaster] { sourceTypes.map { $0.broadcaster } }

    /// One of each source, for a service manager to fetch from.
    static func makeSources() -> [any BroadcasterSource] { sourceTypes.map { $0.init() } }
}
