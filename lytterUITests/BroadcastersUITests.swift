//
//  BroadcastersUITests.swift
//  lytterUITests
//

import XCTest

#if os(iOS)
/// Settings → Broadcasters: show, hide and reorder them (F54b); and Home's chips, one per
/// broadcaster once there are two (F54c).
///
/// Runs on fixtures, with `FixtureSource` — "Testradio", three channels — registered beside
/// DR where a test asks for a second broadcaster. Nothing a test changes here is stored.
final class BroadcastersUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// With DR alone there is nothing to choose, and Settings says nothing about it.
    @MainActor
    func testOneBroadcasterHasNoSettings() throws {
        launch(secondBroadcaster: false)
        openSettings()

        XCTAssertTrue(app.switches["Show Images"].waitForExistence(timeout: 5), "Settings did not load")
        XCTAssertFalse(broadcasterSwitch("DR").exists, "Settings offers to hide the only broadcaster")
    }

    /// Hiding a broadcaster takes its section off Home at once, and showing it brings it back.
    @MainActor
    func testHidingABroadcasterTakesItOffHome() throws {
        launch()
        XCTAssertTrue(homeSection("Testradio").waitForExistence(timeout: 10),
                      "the second broadcaster has no section on Home")

        openSettings()
        let testradio = broadcasterSwitch("Testradio")
        XCTAssertTrue(testradio.waitForExistence(timeout: 5), "Settings does not list the broadcasters")
        shot("broadcasters-settings")
        setSwitch(testradio, on: false)

        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(waitForAbsence(homeSection("Testradio")), "a hidden broadcaster is still on Home")
        XCTAssertTrue(homeSection("DR").exists, "DR left Home with Testradio")

        openSettings()
        setSwitch(broadcasterSwitch("Testradio"), on: true)
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(homeSection("Testradio").waitForExistence(timeout: 10),
                      "a broadcaster shown again did not come back to Home")
    }

    /// A hidden broadcaster's stations are not found by Search either. Two launches: once
    /// a query is typed, the search tab folds the tab bar away.
    @MainActor
    func testAHiddenBroadcasterIsNotSearched() throws {
        launch()
        search("Testradio")
        XCTAssertTrue(searchRow("Testradio Pop").waitForExistence(timeout: 5),
                      "Search does not find the second broadcaster's stations")
        app.terminate()

        launch()
        openSettings()
        setSwitch(broadcasterSwitch("Testradio"), on: false)
        search("Testradio")
        let noResults = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'No Results'")).firstMatch
        XCTAssertTrue(noResults.waitForExistence(timeout: 5),
                      "Search still finds a hidden broadcaster's stations")
        XCTAssertFalse(searchRow("Testradio Pop").exists, "Search still lists Testradio Pop")
    }

    /// The last broadcaster shown cannot be switched off: an app with none would be an
    /// empty screen with nothing to say why.
    @MainActor
    func testTheLastBroadcasterCannotBeHidden() throws {
        launch()
        openSettings()
        let dr = broadcasterSwitch("DR")
        XCTAssertTrue(dr.waitForExistence(timeout: 5), "Settings does not list DR")
        XCTAssertTrue(dr.isEnabled, "DR cannot be hidden while Testradio is shown")

        setSwitch(broadcasterSwitch("Testradio"), on: false)
        XCTAssertFalse(dr.isEnabled, "the last broadcaster shown can be switched off")
    }

    /// Dragging a broadcaster above another puts its section above that one on Home.
    @MainActor
    func testReorderingChangesHome() throws {
        launch()
        XCTAssertTrue(homeSection("Testradio").waitForExistence(timeout: 10), "Home did not load Testradio")
        XCTAssertLessThan(homeSection("DR").frame.minY, homeSection("Testradio").frame.minY,
                          "DR should come first before anything is moved")

        openSettings()
        let testradio = broadcasterSwitch("Testradio")
        XCTAssertTrue(testradio.waitForExistence(timeout: 5), "Settings does not list Testradio")
        // Touch and hold on the name, clear of the switch, then drag above DR.
        let dr = broadcasterSwitch("DR")
        testradio.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
            .press(forDuration: 1.0,
                   thenDragTo: dr.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.1)))
        shot("broadcasters-reordered")

        app.tabBars.buttons["Home"].tap()
        let section = homeSection("Testradio")
        XCTAssertTrue(section.waitForExistence(timeout: 5), "Testradio left Home")
        XCTAssertLessThan(section.frame.minY, homeSection("DR").frame.minY,
                          "Home does not follow the order chosen in Settings")
    }

    // MARK: - Home's chips (F54c)

    /// With DR alone: For you and All, no chip for DR, and no Radio tab — All took it over.
    @MainActor
    func testOneBroadcasterHasForYouAndAll() throws {
        launch(secondBroadcaster: false)

        XCTAssertTrue(chip("forYou").exists, "no For you chip")
        XCTAssertTrue(chip("all").isSelected, "Home did not open on All")
        XCTAssertFalse(chip("broadcaster:dr").exists, "DR has a chip of its own with nothing to tell it from All")
        XCTAssertFalse(app.tabBars.buttons["Radio"].exists, "the Radio tab is still there")
        shot("home-chips-dr-only")
    }

    /// A broadcaster's chip shows its stations and no other's.
    @MainActor
    func testABroadcastersChipShowsItsStations() throws {
        launch()
        let testradio = chip("broadcaster:fixture")
        XCTAssertTrue(testradio.waitForExistence(timeout: 5), "the second broadcaster has no chip")
        XCTAssertTrue(chip("broadcaster:dr").exists, "DR has no chip beside Testradio's")

        testradio.tap()
        XCTAssertTrue(testradio.isSelected, "the chip tapped is not the one selected")
        XCTAssertTrue(card("Testradio Pop").waitForExistence(timeout: 5), "Testradio's stations are not shown")
        XCTAssertTrue(card("Testradio Jazz").exists, "not every Testradio station is shown")
        XCTAssertFalse(card("P1").exists, "DR's stations are shown under Testradio")
        shot("home-chip-testradio")
    }

    /// See all, on a broadcaster's shelf under All, is that broadcaster's chip.
    @MainActor
    func testSeeAllOpensTheBroadcastersChip() throws {
        launch()
        let seeAll = app.buttons["seeAll.Testradio"]
        XCTAssertTrue(seeAll.waitForExistence(timeout: 10), "Testradio's shelf has no See all")
        if !seeAll.isHittable { app.swipeUp() }

        seeAll.tap()
        XCTAssertTrue(chip("broadcaster:fixture").isSelected, "See all did not select Testradio's chip")
        XCTAssertTrue(card("Testradio Pop").waitForExistence(timeout: 5), "Testradio's stations are not shown")
        XCTAssertFalse(card("P1").exists, "DR's stations are still shown")
    }

    /// Hiding the broadcaster Home is showing takes its chip away and leaves Home on All,
    /// where its stations were.
    @MainActor
    func testHidingTheChosenBroadcasterReturnsHomeToAll() throws {
        launch()
        chip("broadcaster:fixture").tap()
        XCTAssertTrue(card("Testradio Pop").waitForExistence(timeout: 5), "Testradio's stations are not shown")

        openSettings()
        setSwitch(broadcasterSwitch("Testradio"), on: false)
        app.tabBars.buttons["Home"].tap()

        XCTAssertTrue(waitForAbsence(chip("broadcaster:fixture")), "a hidden broadcaster still has a chip")
        XCTAssertFalse(chip("broadcaster:dr").exists, "DR kept a chip with no other broadcaster shown")
        XCTAssertTrue(chip("all").isSelected, "Home did not fall back to All")
        XCTAssertTrue(card("P1").waitForExistence(timeout: 5), "All does not show DR's stations")
    }

    // MARK: - Helpers

    @MainActor
    private func launch(secondBroadcaster: Bool = true) {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        if secondBroadcaster { app.launchEnvironment["LYTTER_UITEST_SECOND_BROADCASTER"] = "1" }
        // On All, whatever chip the simulator was last left on: with no favourites and no
        // history that is where Home opens anyway, but a chosen chip is remembered.
        app.launchArguments = [
            "-homeScope", "all",
            "-favouriteChannelIDs", "()",
            "-recentlyPlayedChannelIDs", "()",
            "-recentSearchChannelIDs", "()",
        ]
        app.launch()
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'P1'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20), "Home did not load")
    }

    @MainActor
    private func openSettings() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5),
                      "Settings did not open")
    }

    /// A broadcaster's heading on Home.
    @MainActor
    private func homeSection(_ name: String) -> XCUIElement {
        app.scrollViews.firstMatch.staticTexts[name]
    }

    /// One of Home's chips, by `HomeScope.storageValue`.
    @MainActor
    private func chip(_ scope: String) -> XCUIElement {
        app.buttons["home.scope.\(scope)"]
    }

    /// A station's card on Home, by the station's name.
    @MainActor
    private func card(_ station: String) -> XCUIElement {
        app.scrollViews.firstMatch.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "\(station),")).firstMatch
    }

    @MainActor
    private func broadcasterSwitch(_ name: String) -> XCUIElement {
        app.switches[name]
    }

    @MainActor
    private func search(_ query: String) {
        app.tabBars.buttons["Search"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "no search field")
        field.tap()
        field.typeText(query)
    }

    @MainActor
    private func searchRow(_ title: String) -> XCUIElement {
        app.buttons.matching(identifier: "search.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", "\(title),")).firstMatch
    }

    /// A switch's value is "1" or "0". Tapped on its control rather than the row, which in
    /// an editing list does not toggle.
    @MainActor
    private func setSwitch(_ toggle: XCUIElement, on: Bool) {
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "\(toggle) is missing")
        guard (toggle.value as? String == "1") != on else { return }
        toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.tap()
        let expected = on ? "1" : "0"
        XCTAssertTrue(
            NSPredicate(format: "value == %@", expected).evaluate(with: toggle)
                || XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "value == %@", expected),
                                                    evaluatedWith: toggle)], timeout: 3) == .completed,
            "\(toggle) did not switch \(on ? "on" : "off")")
    }

    @MainActor
    private func waitForAbsence(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "exists == false"),
                                         evaluatedWith: element)], timeout: timeout) == .completed
    }

    @MainActor
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif
