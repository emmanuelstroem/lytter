//
//  SettingsAndSearchUITests.swift
//  lytterUITests
//

import XCTest

#if os(iOS)
/// The Settings tab, which took Shortcuts' place, and Search laid out as Music's is (F43).
///
/// Runs on fixtures (`UITestFixtures`), so the stations are always the same 25 channels.
final class SettingsAndSearchUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Settings

    /// Shortcuts is no longer a tab. Settings says what to ask Siri, and links to the
    /// app's shortcuts with the system's Shortcuts button (F15).
    @MainActor
    func testSiriAndShortcutsLivesInSettings() throws {
        launch()
        XCTAssertFalse(app.tabBars.buttons["Shortcuts"].exists, "Shortcuts is still a tab")

        openSettings()
        XCTAssertTrue(app.switches["Show Images"].waitForExistence(timeout: 5),
                      "Settings has no Show Images switch")

        let link = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'shortcuts'")).firstMatch
        scrollUntilHittable(link)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Say “Play P3”'"))
                        .firstMatch.exists, "Settings does not say what to ask Siri")
        shot("settings")
    }

    /// A region can be chosen in Settings, from every district the catalogue lists, and
    /// "Not Chosen" forgets it (F50). Before, the only way to set one was to find P4.
    @MainActor
    func testChooseRegion() throws {
        launch(region: "Fyn")
        openSettings()

        scrollUntilHittable(regionPicker)
        XCTAssertEqual(regionPicker.label, "Region, Fyn", "Settings does not show the remembered region")

        choose("København")
        XCTAssertEqual(regionPicker.label, "Region, København", "the chosen region is not shown")

        choose("Not Chosen")
        XCTAssertEqual(regionPicker.label, "Region, Not Chosen", "Not Chosen did not forget the region")
    }

    /// Every district is offered, once, though P4 and P5 each broadcast all ten.
    @MainActor
    func testRegionPickerListsEachDistrictOnce() throws {
        launch()
        openSettings()

        scrollUntilHittable(regionPicker)
        regionPicker.tap()
        XCTAssertTrue(app.buttons["Østjylland"].waitForExistence(timeout: 5), "the picker did not open")
        shot("region-picker")
        for district in ["Bornholm", "Esbjerg", "Fyn", "København", "Midt & Vest", "Nordjylland",
                         "Sjælland", "Syd", "Trekanten", "Østjylland"] {
            XCTAssertEqual(app.buttons.matching(identifier: district).count, 1,
                           "\(district) should be offered exactly once")
        }
    }

    // MARK: - Search

    /// Before anything is typed, Search lists every station once: P4 as a station, not
    /// its ten districts.
    @MainActor
    func testSearchOpensOnEveryStation() throws {
        launch()
        app.tabBars.buttons["Search"].tap()

        XCTAssertTrue(app.staticTexts["All Stations"].waitForExistence(timeout: 5),
                      "Search does not open on every station")
        XCTAssertTrue(row("P1").exists, "P1 is not listed")
        XCTAssertTrue(row("P4").exists, "P4 is not listed as a station")
        XCTAssertFalse(row("P4 - Fyn").exists, "P4's districts are listed one by one")
        shot("search-browse")
    }

    /// A district name finds the districts, as channels — not P4 and P5 as stations to
    /// choose a district from again.
    @MainActor
    func testSearchingADistrictListsItsChannels() throws {
        launch()
        app.tabBars.buttons["Search"].tap()

        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "no search field")
        field.tap()
        field.typeText("Fyn")

        XCTAssertTrue(row("P4 - Fyn").waitForExistence(timeout: 5), "P4 Fyn is not a result")
        XCTAssertTrue(row("P5 - Fyn").exists, "P5 Fyn is not a result")
        XCTAssertFalse(row("P1").exists, "P1 should not answer \"Fyn\"")
        XCTAssertFalse(row("P4").exists, "the whole of P4 is listed rather than its Fyn district")
        shot("search-results")
    }

    /// Choosing a result remembers it, and it is listed before anything is typed next time.
    @MainActor
    func testAChosenResultIsRememberedAsARecentSearch() throws {
        launch()
        app.tabBars.buttons["Search"].tap()

        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "no search field")
        field.tap()
        field.typeText("P2")
        let result = row("P2")
        XCTAssertTrue(result.waitForExistence(timeout: 5), "P2 is not a result")
        // A tap while the keyboard is still settling can be dropped; the mini player taking
        // P2 is the sign it landed. Once more if not — this test is about what is remembered.
        let playing = app.descendants(matching: .any).matching(identifier: "miniPlayer")
            .matching(NSPredicate(format: "label BEGINSWITH 'P2'")).firstMatch
        result.tap()
        if !playing.waitForExistence(timeout: 5) { result.tap() }
        XCTAssertTrue(playing.waitForExistence(timeout: 5), "choosing P2 did not start it")

        // Clear the query, which returns to the browse screen.
        field.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Recently Searched"].waitForExistence(timeout: 5),
                      "no Recently Searched section after choosing a result")
        XCTAssertTrue(row("P2").exists, "P2 is not among the recent searches")
    }

    // MARK: - Launch

    /// The app opens on Home, whichever tab was showing when it was last left. It used to
    /// restore the last tab, so a listener who had last searched came back to Search.
    @MainActor
    func testLaunchOpensOnHomeNotTheLastTab() throws {
        launch()
        app.tabBars.buttons["Search"].tap()
        XCTAssertTrue(app.staticTexts["All Stations"].waitForExistence(timeout: 5),
                      "Search did not open")

        // Leave through the home screen, which is when scene state is saved, then come back.
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5)
                      || app.wait(for: .runningBackgroundSuspended, timeout: 5))
        app.terminate()
        launch()

        XCTAssertTrue(app.tabBars.buttons["Home"].isSelected, "the app did not open on Home")
        XCTAssertFalse(app.staticTexts["All Stations"].exists, "the app reopened on Search")
    }

    // MARK: - Helpers

    /// The Region picker, whose label carries the choice: "Region, Fyn".
    @MainActor
    private var regionPicker: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Region, '")).firstMatch
    }

    @MainActor
    private func choose(_ option: String) {
        regionPicker.tap()
        let row = app.buttons[option]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the picker does not offer \(option)")
        row.tap()
    }

    @MainActor
    private func launch(favourites: [String] = [], region: String? = nil) {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        // The argument domain overrides stored defaults for this launch only.
        app.launchArguments = [
            "-favouriteChannelIDs", plistArray(favourites.map { "urn:fixture:\($0)" }),
            "-recentlyPlayedChannelIDs", "()",
            "-recentSearchChannelIDs", "()",
            "-preferredDistrictName", region ?? ""
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

    /// A result row, by the station or channel it names. By identifier as well as label:
    /// the mini player's label starts with the station's name too.
    @MainActor
    private func row(_ title: String) -> XCUIElement {
        app.buttons.matching(identifier: "search.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", "\(title),")).firstMatch
    }

    @MainActor
    private func scrollUntilHittable(_ element: XCUIElement) {
        for _ in 0..<5 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "\(element) never came into reach")
    }

    @MainActor
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func plistArray(_ values: [String]) -> String {
        "(" + values.map { "\"\($0)\"" }.joined(separator: ",") + ")"
    }
}
#endif
