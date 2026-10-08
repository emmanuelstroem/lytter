//
//  VisionLaunchUITests.swift
//  lytterUITests
//

import XCTest

#if os(visionOS)
/// The app on Apple Vision Pro has something in its window.
///
/// It once launched to an empty one: the app target listed visionOS, but `ContentView` had a
/// branch for every other platform and none for it, so the window was blank glass. These run
/// on fixtures (`UITestFixtures`), so there is always a station to find.
final class VisionLaunchUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Home opens with its chips and the stations.
    @MainActor
    func testHomeShowsTheStations() throws {
        launch()
        XCTAssertTrue(app.buttons["home.scope.all"].waitForExistence(timeout: 20),
                      "Home's chips are not in the window")
        XCTAssertTrue(card("P1").waitForExistence(timeout: 20), "no station on Home")
    }

    /// Playing a station brings up the mini player below the window, and the mini player
    /// opens the full player.
    @MainActor
    func testPlayingShowsTheMiniPlayer() throws {
        launch()
        let miniPlayer = app.descendants(matching: .any)["miniPlayer"]
        XCTAssertFalse(miniPlayer.exists, "the mini player is up before anything has played")

        let p1 = card("P1")
        XCTAssertTrue(p1.waitForExistence(timeout: 20), "no station on Home")
        p1.tap()

        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 10),
                      "playing a station did not bring up the mini player")
        miniPlayer.tap()
        XCTAssertTrue(app.staticTexts["player.title"].waitForExistence(timeout: 20),
                      "the mini player did not open the full player")
    }

    /// The full player closes when the window around it is tapped. It was a sheet, which
    /// on visionOS nothing can drag away, and it had no close button: once open, it stayed.
    @MainActor
    func testTappingOutsideTheFullPlayerClosesIt() throws {
        launch()
        let p1 = card("P1")
        XCTAssertTrue(p1.waitForExistence(timeout: 20), "no station on Home")
        p1.tap()
        let miniPlayer = app.descendants(matching: .any)["miniPlayer"]
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 10), "no mini player after playing P1")
        miniPlayer.tap()

        let title = app.staticTexts["player.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 20), "the mini player did not open the full player")

        // Beside the panel, which stands in the middle of the window.
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5)).tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 10),
                      "tapping the window beside the full player did not close it")
    }

    /// For you, chosen last time but with nothing in it, gives way to All: Home should not
    /// open on a page that only says what will come there.
    @MainActor
    func testAnEmptyForYouOpensOnAll() throws {
        launch(homeScope: "forYou")
        let all = app.buttons["home.scope.all"]
        XCTAssertTrue(all.waitForExistence(timeout: 20), "Home's chips are not in the window")
        XCTAssertTrue(card("P1").waitForExistence(timeout: 20), "Home did not open on the stations")
        XCTAssertTrue(all.isSelected, "Home opened on an empty For you rather than All")
    }

    /// Search and Settings are there, in the tab ornament.
    @MainActor
    func testSearchAndSettingsOpen() throws {
        launch()
        XCTAssertTrue(card("P1").waitForExistence(timeout: 20), "Home did not load")

        tab("Search").tap()
        XCTAssertTrue(app.descendants(matching: .any)["search.row"].firstMatch
                          .waitForExistence(timeout: 10)
                      || app.staticTexts["All Stations"].waitForExistence(timeout: 10),
                      "Search did not open")

        tab("Settings").tap()
        XCTAssertTrue(app.switches["Show Images"].waitForExistence(timeout: 10),
                      "Settings did not open")
    }

    /// On fixtures, on All, with nothing remembered, so Home opens on every station. No
    /// last station either: the app brings that back paused, mini player and all.
    @MainActor
    private func launch(homeScope: String = "all") {
        app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        app.launchArguments = [
            "-homeScope", homeScope,
            // Every key it is found by, not only the id: it is matched on title and name too.
            "-lastPlayedChannelId", "",
            "-lastPlayedChannelTitle", "",
            "-lastPlayedChannelName", "",
            "-favouriteChannelIDs", "()",
            "-recentlyPlayedChannelIDs", "()",
            "-recentSearchChannelIDs", "()",
        ]
        app.launch()
    }

    /// A station's card on Home, by the station's name.
    @MainActor
    private func card(_ station: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(station),")).firstMatch
    }

    /// One of the tabs in the ornament on the window's leading edge.
    @MainActor
    private func tab(_ name: String) -> XCUIElement {
        let inTabBar = app.tabBars.buttons[name]
        return inTabBar.exists ? inTabBar : app.buttons[name].firstMatch
    }
}
#endif
