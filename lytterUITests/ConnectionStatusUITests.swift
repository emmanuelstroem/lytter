//
//  ConnectionStatusUITests.swift
//  lytterUITests
//

import XCTest

/// What Home says when the network is the problem (F42), on iOS and tvOS alike.
///
/// The conditions are simulated (`LYTTER_UITEST_NETWORK`, see `UITestFixtures`), so these
/// run the same whatever the machine is connected to, and never touch its network.
final class ConnectionStatusUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Offline with nothing cached: say so, full screen, rather than spin.
    @MainActor
    func testOfflineWithNothingCachedSaysOffline() throws {
        let app = launch(network: "offline")

        XCTAssertTrue(element(app, labelStartingWith: "You're offline").waitForExistence(timeout: 15),
                      "Home did not say it was offline")
        XCTAssertTrue(app.buttons["Try Again"].exists, "no way to try again")
        XCTAssertFalse(card(app, "P1").exists, "channels appeared with no connection")
    }

    /// Offline over cached channels: the channels stay, with the banner over them.
    @MainActor
    func testOfflineOverCachedChannelsShowsTheBanner() throws {
        let app = launch(network: "offline-cached")

        XCTAssertTrue(card(app, "P1").waitForExistence(timeout: 15), "the cached channels are not shown")
        XCTAssertTrue(element(app, labelStartingWith: "You're offline").exists,
                      "nothing says the channels may be out of date")
    }

    /// Online, but DR's API failing: a different message from offline.
    @MainActor
    func testDRDownSaysDRIsNotAnswering() throws {
        let app = launch(network: "dr-down")

        XCTAssertTrue(element(app, labelStartingWith: "DR isn't answering").waitForExistence(timeout: 15),
                      "Home did not say DR was not answering")
        XCTAssertFalse(element(app, labelStartingWith: "You're offline").exists,
                       "DR being down was reported as the listener being offline")
    }

    /// Back online, the channels load by themselves, with no Try Again pressed.
    @MainActor
    func testChannelsLoadByThemselvesWhenTheConnectionReturns() throws {
        let app = launch(network: "reconnects")

        XCTAssertTrue(element(app, labelStartingWith: "You're offline").waitForExistence(timeout: 15),
                      "the test needs Home to start offline")
        XCTAssertTrue(card(app, "P1").waitForExistence(timeout: 20),
                      "the channels did not load when the connection came back")
        XCTAssertFalse(element(app, labelStartingWith: "You're offline").exists,
                       "still saying offline after reconnecting")
    }

    // MARK: - Helpers

    @MainActor
    private func launch(network: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        app.launchEnvironment["LYTTER_UITEST_NETWORK"] = network
        app.launchArguments = ["-favouriteChannelIDs", "()", "-recentlyPlayedChannelIDs", "()"]
        app.launch()
        return app
    }

    @MainActor
    private func element(_ app: XCUIApplication, labelStartingWith prefix: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    @MainActor
    private func card(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }
}
