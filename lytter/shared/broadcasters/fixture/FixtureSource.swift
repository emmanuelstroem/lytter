//
//  FixtureSource.swift
//  lytter
//

import Foundation

#if DEBUG
/// A second broadcaster for UI tests, so what appears only once there are two — Settings →
/// Broadcasters (F54b), the Home chips (F54c) — can be driven before a real one exists.
///
/// Registered only when a UI test asks for it with `LYTTER_UITEST_SECOND_BROADCASTER`, and
/// compiled into debug builds only. Its channels play nothing, as the fixtures' DR channels
/// do not.
final class FixtureSource: BroadcasterSource {

    static let broadcaster = Broadcaster(id: "fixture", name: "Testradio", displayOrder: 1)

    init() {}

    func fetchCatalogue() async throws -> [DREpisode] {
        try UITestFixtures.secondBroadcasterResponse()
    }
}
#endif
