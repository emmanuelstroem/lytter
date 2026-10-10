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

        app.tab("Home").tap()
        XCTAssertTrue(waitForAbsence(homeSection("Testradio")), "a hidden broadcaster is still on Home")
        XCTAssertTrue(homeSection("DR").exists, "DR left Home with Testradio")

        openSettings()
        setSwitch(broadcasterSwitch("Testradio"), on: true)
        app.tab("Home").tap()
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
        // Touch and hold on the name, clear of the switch, until the row lifts; then drag it
        // above DR, slowly, and hold there so the drop lands where it was aimed.
        let dr = broadcasterSwitch("DR")
        let moved = { testradio.frame.minY < dr.frame.minY }
        let drag = {
            testradio.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
                .press(forDuration: 2.0,
                       thenDragTo: dr.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.1)),
                       withVelocity: .slow, thenHoldForDuration: 0.5)
            // The rows' frames mean nothing while the drop animates; read them once it has.
            sleep(1)
        }
        drag()
        // Now and then the simulator lifts the row only after the drag has gone by, and it
        // drops where it was (one run in three on the iPad Pro 13-inch); once more if so.
        // This test is about Home following Settings, not about the gesture.
        if !moved() { drag() }
        // Leaving Settings before the drop had landed took Home the old order (B14).
        XCTAssertTrue(eventually(moved), "Settings did not take the new order")
        shot("broadcasters-reordered")

        app.tab("Home").tap()
        let section = homeSection("Testradio")
        XCTAssertTrue(section.waitForExistence(timeout: 5), "Testradio left Home")
        XCTAssertTrue(eventually { section.frame.minY < self.homeSection("DR").frame.minY },
                      "Home does not follow the order chosen in Settings")
    }

    // MARK: - Home's chips (F54c)

    /// With DR alone: For you, All and DR, and no Radio tab — All took it over.
    @MainActor
    func testOneBroadcasterHasForYouAllAndItsOwnChip() throws {
        launch(secondBroadcaster: false)

        XCTAssertTrue(chip("forYou").exists, "no For you chip")
        XCTAssertTrue(chip("all").isSelected, "Home did not open on All")
        XCTAssertTrue(chip("broadcaster:dr").exists, "DR has no chip while it is the only broadcaster")
        XCTAssertFalse(app.tab("Radio").exists, "the Radio tab is still there")
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

    /// A broadcaster's chip is its stations, each once, A to Z: a favourite is not listed
    /// again above them, as it was when P4 appeared twice.
    @MainActor
    func testABroadcastersChipListsEachStationOnceInOrder() throws {
        launch(secondBroadcaster: false, favourites: ["p3", "p1"])
        chip("broadcaster:dr").tap()
        XCTAssertTrue(card("P1").waitForExistence(timeout: 5), "DR's stations are not shown")

        let p1Cards = app.scrollViews.firstMatch.buttons.matching(NSPredicate(format: "label BEGINSWITH 'P1,'"))
        XCTAssertEqual(p1Cards.count, 1, "a favourite is listed twice on its broadcaster's chip")
        XCTAssertFalse(app.scrollViews.firstMatch.staticTexts["Favourites"].exists,
                       "the broadcaster's chip still has a Favourites shelf")
        XCTAssertTrue(readsBefore(card("P1").frame, card("P3").frame),
                      "P1 is not first: the stations are not in order")
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
        app.tab("Home").tap()

        XCTAssertTrue(waitForAbsence(chip("broadcaster:fixture")), "a hidden broadcaster still has a chip")
        XCTAssertTrue(chip("broadcaster:dr").exists, "DR lost its chip when Testradio was hidden")
        XCTAssertTrue(chip("all").isSelected, "Home did not fall back to All")
        XCTAssertTrue(card("P1").waitForExistence(timeout: 5), "All does not show DR's stations")
    }

    /// Showing that broadcaster again leaves Home on All. Home fell back there; the chip
    /// is not taken up again behind the listener's back.
    @MainActor
    func testShowingTheBroadcasterAgainLeavesHomeOnAll() throws {
        launch()
        chip("broadcaster:fixture").tap()
        XCTAssertTrue(card("Testradio Pop").waitForExistence(timeout: 5), "Testradio's stations are not shown")

        openSettings()
        setSwitch(broadcasterSwitch("Testradio"), on: false)
        app.tab("Home").tap()
        XCTAssertTrue(waitForAbsence(chip("broadcaster:fixture")), "a hidden broadcaster still has a chip")

        openSettings()
        setSwitch(broadcasterSwitch("Testradio"), on: true)
        app.tab("Home").tap()

        XCTAssertTrue(chip("broadcaster:fixture").waitForExistence(timeout: 5), "Testradio's chip did not return")
        XCTAssertTrue(chip("all").isSelected, "Home jumped back to Testradio's chip")
        XCTAssertFalse(chip("broadcaster:fixture").isSelected, "Home jumped back to Testradio's chip")
    }

    // MARK: - Helpers

    @MainActor
    private func launch(secondBroadcaster: Bool = true, favourites: [String] = []) {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        if secondBroadcaster { app.launchEnvironment["LYTTER_UITEST_SECOND_BROADCASTER"] = "1" }
        // On All, whatever chip the simulator was last left on: with no favourites and no
        // history that is where Home opens anyway, but a chosen chip is remembered.
        app.launchArguments = [
            "-homeScope", "all",
            "-favouriteChannelIDs", "(" + favourites.map { "\"urn:fixture:\($0)\"" }.joined(separator: ",") + ")",
            "-recentlyPlayedChannelIDs", "()",
            "-recentSearchChannelIDs", "()",
        ]
        app.launch()
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'P1'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20), "Home did not load")
    }

    @MainActor
    private func openSettings() {
        app.tab("Settings").tap()
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

    /// Whether `a` comes before `b` in reading order: the row first, then the column. On
    /// iPhone the cards are one above another; iPad's wider grid sets several side by side.
    private func readsBefore(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minY - b.minY) < 1 ? a.minX < b.minX : a.minY < b.minY
    }

    @MainActor
    private func broadcasterSwitch(_ name: String) -> XCUIElement {
        app.switches[name]
    }

    @MainActor
    private func search(_ query: String) {
        app.tab("Search").tap()
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

    /// Whether `condition` holds within `timeout`, asked again every quarter of a second.
    @MainActor
    private func eventually(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else { return false }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return true
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
