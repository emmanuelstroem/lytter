//
//  TVScrollingUITests.swift
//  lytterUITests
//

import XCTest

#if os(tvOS)
/// Every surface on Apple TV that holds more than fits on screen, driven with the remote.
///
/// On tvOS a list scrolls only to bring focus into view. A scroll view holding nothing
/// focusable does not scroll at all, and nothing warns: it looks right in a screenshot and
/// sits still under the remote. The schedule sheet and the info sheet's description both
/// shipped that way, and were found by hand. These tests are why the next one will not be.
///
/// Each test presses the remote the way a viewer would and checks that what should come
/// into view did. The app runs on fixtures (`UITestFixtures`), so there is always more
/// content than fits, whatever DR is broadcasting.
///
/// `TVScrollingCoverageTests` fails if a scrolling container appears in tvOS code without
/// being listed against one of these tests.
final class TVScrollingUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Home

    /// Home is one vertical list of shelves. With Favourites and Recently Played on top, the
    /// DR shelf starts below the screen, and pressing down has to bring it up.
    @MainActor
    func testHomeScrollsDownToLowerShelves() throws {
        launch(favourites: ["p1", "p2", "p3"], recentlyPlayed: ["p6", "p8", "p3"])

        let drHeading = app.staticTexts["DR"]
        XCTAssertFalse(isOnScreen(drHeading), "the test needs the DR shelf to start off screen")

        press(.down, times: 2)

        XCTAssertTrue(isOnScreen(drHeading), "pressing down did not bring the DR shelf into view")
        XCTAssertTrue(isOnScreen(focused), "focus moved somewhere that is not on screen")
    }

    /// A shelf is a horizontal list of cards. Pressing right along it has to keep bringing
    /// the next card into view, all the way to the last.
    @MainActor
    func testShelfScrollsSideways() throws {
        launch()
        let lastCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'P8'")).firstMatch
        XCTAssertFalse(isOnScreen(lastCard), "the test needs the last card to start off screen")

        XCTAssertTrue(moveFocus(.right, until: { $0.label.hasPrefix("P8") }),
                      "pressing right never reached the last card; focus is on \(focusedLabel)")
        XCTAssertTrue(isOnScreen(focused), "the last card has focus but is off screen")
    }

    /// Favourite shows are a shelf of their own (F33). With ten pinned the row runs off the
    /// screen, and pressing right along it has to reach the last show.
    @MainActor
    func testShowShelfScrollsSideways() throws {
        launch(favouriteShows: 10)
        XCTAssertTrue(app.staticTexts["Shows"].waitForExistence(timeout: 10),
                      "the Shows shelf did not appear")
        let lastShow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Fixture-serie 10'")).firstMatch
        XCTAssertFalse(isOnScreen(lastShow), "the test needs the last show to start off screen")

        XCTAssertTrue(moveFocus(.up, until: { $0.label.hasPrefix("Fixture-serie") }, maxPresses: 4),
                      "could not reach the Shows shelf; focus is on \(focusedLabel)")
        XCTAssertTrue(moveFocus(.right, until: { $0.label.hasPrefix("Fixture-serie 10") }),
                      "pressing right never reached the last show; focus is on \(focusedLabel)")
        XCTAssertTrue(isOnScreen(focused), "the last show has focus but is off screen")
        shot("show-shelf-end")
    }

    // MARK: - Radio and Search

    /// Radio is one horizontal row of every station. Pressing right has to reach the last.
    @MainActor
    func testRadioShelfScrollsSideways() throws {
        launch()
        openSection("Radio")

        XCTAssertTrue(moveFocus(.right, until: { $0.label.hasPrefix("P8") }, maxPresses: 16),
                      "pressing right never reached the last station; focus is on \(focusedLabel)")
        XCTAssertTrue(isOnScreen(focused), "the last station has focus but is off screen")
    }

    /// Once something is typed, results are shelves, as in Music. "P" names every station,
    /// so the Stations shelf runs off the screen, and pressing right has to reach its end.
    @MainActor
    func testSearchResultShelfScrollsSideways() throws {
        launch()
        openSection("Search")
        app.typeText("P")
        shot("search-typed")

        XCTAssertTrue(app.staticTexts["Stations"].waitForExistence(timeout: 5),
                      "typing did not show the results shelves")
        XCTAssertTrue(moveFocus(.down, until: { $0.label.hasPrefix("P1") }, maxPresses: 8),
                      "could not move from the keyboard to the results; focus is on \(focusedLabel)")
        XCTAssertTrue(moveFocus(.right, until: { $0.label.hasPrefix("P8") }, maxPresses: 10),
                      "pressing right never reached the last result; focus is on \(focusedLabel)")
        XCTAssertTrue(isOnScreen(focused), "the last result has focus but is off screen")
        shot("search-shelf-end")
    }

    /// Search lists every station under the keyboard. Moving down into the results and on
    /// to the last row has to bring that row into view.
    @MainActor
    func testSearchResultsScroll() throws {
        launch()
        openSection("Search")

        XCTAssertTrue(moveFocus(.down, until: { $0.label.hasPrefix("P") }, maxPresses: 10),
                      "could not move from the search field into the results; focus is on \(focusedLabel)")
        XCTAssertTrue(moveFocus(.down, until: { $0.label.hasPrefix("P5") || $0.label.hasPrefix("P6")
                                                 || $0.label.hasPrefix("P8") }, maxPresses: 4),
                      "could not move to the last row of results; focus is on \(focusedLabel)")
        XCTAssertTrue(isOnScreen(focused), "a result in the last row has focus but is off screen")
    }

    // MARK: - Sidebar

    /// Search heads the sidebar, as in the TV and Music apps (F36), and Settings ends it
    /// (F37). Not a scrolling surface, but these tests already know how to walk the sidebar.
    @MainActor
    func testSidebarOrder() throws {
        launch()
        let destinations = ["Search", "Home", "Radio", "Now Playing", "Settings"]
        XCTAssertTrue(moveFocus(.left, until: { destinations.contains($0.label) }, maxPresses: 8),
                      "could not move into the sidebar; focus is on \(focusedLabel)")
        press(.up, times: destinations.count)

        var order = [focusedLabel]
        for _ in 1..<destinations.count {
            press(.down)
            order.append(focusedLabel)
        }
        shot("sidebar-order")
        XCTAssertEqual(order, destinations)
    }

    // MARK: - Settings

    /// Settings is a form taller than the screen. Pressing down has to walk it to the last
    /// row, and the last row has to be on screen when it gets there.
    @MainActor
    func testSettingsScrolls() throws {
        // Favourites, history and a region, so every row is enabled and can take focus.
        launch(favourites: ["p1"], recentlyPlayed: ["p2"], region: "Fyn")
        openSection("Settings")

        XCTAssertTrue(moveFocus(.down, until: { $0.label.hasPrefix("Version") }, maxPresses: 12),
                      "pressing down never reached the last row; focus is on \(focusedLabel)")
        XCTAssertTrue(isOnScreen(focused), "the last row has focus but is off screen")
    }

    /// Settings' Region picker (F50) pushes a list of every district plus "Not Chosen".
    /// Pressing down has to reach the last one with it on screen, and choosing it has to
    /// come back to Settings showing it.
    @MainActor
    func testRegionPickerScrolls() throws {
        launch(region: "Fyn")
        openSection("Settings")

        XCTAssertTrue(moveFocus(.down, until: { $0.label.hasPrefix("Region") }, maxPresses: 8),
                      "could not reach the Region row; focus is on \(focusedLabel)")
        press(.select)
        XCTAssertTrue(app.buttons["Østjylland"].waitForExistence(timeout: 5),
                      "the region list did not open")

        XCTAssertTrue(moveFocus(.down, until: { $0.label.hasPrefix("Østjylland") }, maxPresses: 14),
                      "pressing down never reached the last district; focus is on \(focusedLabel)")
        XCTAssertTrue(isOnScreen(focused), "the last district has focus but is off screen")
        shot("region-list-bottom")

        press(.select)
        sleep(1)
        XCTAssertTrue(focused.waitForExistence(timeout: 5), "nothing has focus after choosing")
        shot("after-choosing")
        XCTAssertEqual(focusedLabel, "Region",
                       "choosing should return to the Region row; focus is on \(focusedLabel)")
        // The focused row is a cell; the choice is the value of the button inside it.
        let row = focused.buttons["Region"].firstMatch
        XCTAssertEqual(row.value as? String, "Østjylland", "Settings should show the chosen region")
    }

    // MARK: - District picker

    /// The picker is one column of ten districts, taller than its panel. Pressing down has to
    /// walk it to the last one, and the last one has to be visible when it gets there.
    @MainActor
    func testDistrictPickerScrolls() throws {
        launch(region: "Nordjylland")

        XCTAssertTrue(moveFocus(.right, until: { $0.label.hasPrefix("P4") }), "could not reach P4")
        press(.select)
        XCTAssertTrue(app.buttons["Nordjylland"].waitForExistence(timeout: 5),
                      "the district picker did not open")
        XCTAssertTrue(app.buttons["Nordjylland"].hasFocus,
                      "the listener's own region should have focus when the picker opens")

        press(.down, times: 9)

        XCTAssertEqual(focusedLabel, "Østjylland")
        XCTAssertTrue(isOnScreen(focused), "the last district has focus but is off screen")
    }

    // MARK: - Player

    /// Today's schedule is thirty programmes, far more than the sheet shows. Pressing down has
    /// to reach the last one, and up the first.
    @MainActor
    func testScheduleScrolls() throws {
        launch()
        openPlayer()

        XCTAssertTrue(moveFocus(.right, until: { $0.label == "Schedule" }),
                      "could not reach the schedule button; focus is on \(focusedLabel)")
        press(.select)
        let rows = app.descendants(matching: .any).matching(identifier: "schedule.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5), "the schedule did not open")

        // The fixture puts the programme on air now at number 16 of 30.
        sleep(1)
        XCTAssertTrue(focusedLabel.contains("Fixture-program 16"),
                      "the schedule should open on the programme on air; focus is on \(focusedLabel)")

        XCTAssertTrue(moveFocus(.down, until: { $0.label.contains("Fixture-program 30") },
                                maxPresses: 20),
                      "pressing down did not reach the last programme; focus is on \(focusedLabel)")
        XCTAssertTrue(isOnScreen(focused), "the last programme has focus but is off screen")

        XCTAssertTrue(moveFocus(.up, until: { $0.label.contains("Fixture-program 1,")
                                               || $0.label.hasSuffix("Fixture-program 1") },
                                maxPresses: 35),
                      "pressing up did not reach the first programme; focus is on \(focusedLabel)")
        XCTAssertTrue(isOnScreen(focused), "the first programme has focus but is off screen")
    }

    /// A finished programme with a recording is a button in the schedule (F16). Selecting
    /// it closes the sheet onto the player, which then shows the recording rather than what
    /// is on air. The fixtures give every other finished programme one; 15 has it.
    @MainActor
    func testScheduleCatchUpRowPlaysTheRecording() throws {
        launch()
        openPlayer()

        XCTAssertTrue(moveFocus(.right, until: { $0.label == "Schedule" }),
                      "could not reach the schedule button; focus is on \(focusedLabel)")
        press(.select)
        let rows = app.descendants(matching: .any).matching(identifier: "schedule.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5), "the schedule did not open")
        sleep(1)

        XCTAssertTrue(moveFocus(.up, until: { $0.label.contains("Fixture-program 15") },
                                maxPresses: 3),
                      "could not reach the finished programme; focus is on \(focusedLabel)")
        press(.select)

        let position = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Position'")).firstMatch
        XCTAssertTrue(position.waitForExistence(timeout: 5),
                      "the player did not switch to the recording")
        XCTAssertFalse(rows.firstMatch.exists, "the schedule stayed open")
        // By its series, as the player names every programme that has one (F33 gave the
        // fixtures series; programme 15 is the fifth).
        XCTAssertTrue(app.staticTexts["Fixture-serie 5"].exists,
                      "the player does not name the recording")
    }

    /// Holding select on a schedule row offers to pin its show (F33), and the show then has
    /// a shelf on Home. The row on air is read-only — focusable, not a button — which is
    /// the kind tvOS gives no context menu unless it is attached to the focused view.
    @MainActor
    func testScheduleRowPinsItsShow() throws {
        launch()
        openPlayer()

        XCTAssertTrue(moveFocus(.right, until: { $0.label == "Schedule" }),
                      "could not reach the schedule button; focus is on \(focusedLabel)")
        press(.select)
        let rows = app.descendants(matching: .any).matching(identifier: "schedule.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5), "the schedule did not open")
        sleep(1)
        XCTAssertTrue(focusedLabel.contains("Fixture-program 16"),
                      "the schedule should open on the programme on air; focus is on \(focusedLabel)")

        XCUIRemote.shared.press(.select, forDuration: 1.5)
        let pin = app.buttons["Add Show to Favourites"]
        XCTAssertTrue(pin.waitForExistence(timeout: 5), "holding select offered no way to pin the show")
        shot("schedule-pin-menu")
        // The menu opens with its one item focused, in a window of its own where focus is
        // not reported; select takes it.
        press(.select)

        // Out of the schedule, then out of Now Playing, which Menu takes back to Home.
        press(.menu)
        press(.menu)
        XCTAssertTrue(app.staticTexts["Shows"].waitForExistence(timeout: 5),
                      "Home has no Shows shelf after pinning")
        let show = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Fixture-serie 6'")).firstMatch
        XCTAssertTrue(show.exists, "the pinned show is not on the Shows shelf")
    }

    /// The fixture description is several paragraphs, longer than the info sheet. A click
    /// down has to move the text, and a click up has to move it back.
    @MainActor
    func testInfoDescriptionScrolls() throws {
        launch()
        openPlayer()

        XCTAssertTrue(moveFocus(.left, until: { $0.label.localizedCaseInsensitiveContains("info") }),
                      "could not reach the info button; focus is on \(focusedLabel)")
        let description = app.textViews["info.description"]
        // The info button has taken two presses to open the sheet in the simulator; see the
        // PR notes. This test is about scrolling, so it does not depend on the first.
        for _ in 0..<3 where !description.exists {
            press(.select)
            _ = description.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(description.exists, "the info sheet did not open")

        let top = description.screenshot().pngRepresentation
        press(.down)
        let scrolled = description.screenshot().pngRepresentation
        XCTAssertNotEqual(top, scrolled, "clicking down did not scroll the description")

        press(.up)
        let back = description.screenshot().pngRepresentation
        XCTAssertNotEqual(scrolled, back, "clicking up did not scroll the description back")
    }

    // MARK: - Helpers
    //
    // @MainActor: XCUIApplication and XCUIElement are main-actor API under Swift 6. The
    // tests already were; the helpers they call were not, which was ~35 warnings that only
    // a tvOS build shows (S16).

    @MainActor
    private func launch(favourites: [String] = [], recentlyPlayed: [String] = [],
                        region: String? = nil, favouriteShows: Int = 0) {
        app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        app.launchEnvironment["LYTTER_UITEST_FAVOURITE_SHOWS"] = String(favouriteShows)
        // The argument domain overrides stored defaults for this launch only, so a test's
        // favourites never become the simulator's.
        app.launchArguments = [
            "-favouriteChannelIDs", plistArray(favourites.map { "urn:fixture:\($0)" }),
            "-recentlyPlayedChannelIDs", plistArray(recentlyPlayed.map { "urn:fixture:\($0)" }),
            "-preferredDistrictName", region ?? ""
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["DR"].waitForExistence(timeout: 15)
                        || app.otherElements.containing(NSPredicate(format: "label BEGINSWITH 'P1'"))
                            .firstMatch.waitForExistence(timeout: 5),
                      "Home did not load")
        // Wait for focus to land somewhere; until it has, the first press only places it.
        XCTAssertTrue(focused.waitForExistence(timeout: 10), "nothing took focus on Home")
    }

    /// Opens a sidebar destination. Left from the first card moves focus into the sidebar —
    /// not Menu, which from Home leaves the app altogether.
    @MainActor
    private func openSection(_ name: String) {
        let destinations = ["Search", "Home", "Radio", "Now Playing", "Settings"]
        XCTAssertTrue(moveFocus(.left, until: { destinations.contains($0.label) }, maxPresses: 8),
                      "could not move into the sidebar; focus is on \(focusedLabel)")
        shot("in-sidebar")
        let reached = moveFocus(.down, until: { $0.label == name }, maxPresses: 6)
            || moveFocus(.up, until: { $0.label == name }, maxPresses: 6)
        XCTAssertTrue(reached, "could not find \(name) in the sidebar; focus is on \(focusedLabel)")
        press(.select)
        sleep(2)
        shot("after-selecting-\(name)")
        // Selecting a destination can leave focus in the sidebar; step into the content.
        if destinations.contains(focusedLabel) { press(.right) }
    }

    /// Plays P2 from Home, which switches to Now Playing.
    @MainActor
    private func openPlayer() {
        XCTAssertTrue(moveFocus(.right, until: { $0.label.hasPrefix("P2") }), "could not reach P2")
        press(.select)
        sleep(4)
    }

    /// Presses `button` until the focused element satisfies `matches`, rather than counting
    /// presses: how many it takes depends on where focus settled, and a count that is off by
    /// one tests the wrong card.
    @MainActor
    @discardableResult
    private func moveFocus(_ button: XCUIRemote.Button,
                           until matches: (XCUIElement) -> Bool,
                           maxPresses: Int = 12) -> Bool {
        for _ in 0..<maxPresses {
            if focused.exists && matches(focused) { return true }
            press(button)
        }
        return focused.exists && matches(focused)
    }

    @MainActor
    private var focused: XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "hasFocus == true")).firstMatch
    }

    /// The focused element's label, or "" while nothing has focus — reading `label` from an
    /// element that does not exist fails the test rather than returning nothing.
    @MainActor
    private var focusedLabel: String {
        focused.exists ? focused.label : ""
    }

    @MainActor
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .deleteOnSuccess
        add(attachment)
    }

    @MainActor
    private func isOnScreen(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let screen = app.windows.firstMatch.frame
        let frame = element.frame
        return !frame.isEmpty && screen.contains(CGPoint(x: frame.midX, y: frame.midY))
    }

    @MainActor
    private func press(_ button: XCUIRemote.Button, times: Int = 1) {
        for _ in 0..<times {
            XCUIRemote.shared.press(button)
            // Focus moves and scrolling animate; give each press time to land.
            usleep(600_000)
        }
    }

    private func plistArray(_ values: [String]) -> String {
        "(" + values.map { "\"\($0)\"" }.joined(separator: ",") + ")"
    }
}
#endif
