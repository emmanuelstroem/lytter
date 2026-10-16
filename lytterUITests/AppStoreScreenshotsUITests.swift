//
//  AppStoreScreenshotsUITests.swift
//  lytterUITests
//

import XCTest

/// The App Store screenshots: each test walks one platform's screens on the showcase
/// fixtures (`UITestFixtures+Showcase`) and asks for a screenshot at each.
///
/// Run by `Tools/export-screenshots.sh`, never on its own: without `LYTTER_SCREENSHOT_DIR`
/// every test here skips. The script takes the screenshots, not the test. The visionOS
/// simulator cannot take one from inside a test (B12), and `simctl io screenshot` can on
/// every platform, at the size App Store Connect asks for. So `capture(_:)` writes the
/// screenshot's name into the shared directory and waits; the script, watching it, takes
/// the screenshot and deletes the request.
///
/// In both of the store's languages, from `LYTTER_SCREENSHOT_LOCALE`: the programmes are
/// Danish either way, as DR's are, and only the app's own words change.
final class AppStoreScreenshotsUITests: XCTestCase {

    private var app: XCUIApplication!
    private var directory: URL!
    private var isDanish = false

    override func setUpWithError() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["LYTTER_SCREENSHOT_DIR"], !path.isEmpty else {
            throw XCTSkip("Run by Tools/export-screenshots.sh, which takes the screenshots")
        }
        directory = URL(fileURLWithPath: path)
        isDanish = environment["LYTTER_SCREENSHOT_LOCALE"] == "da"
        continueAfterFailure = false
    }

    #if os(iOS)
    /// iPhone and iPad: Home, the player, its schedule, *For you* and Search.
    @MainActor
    func testPhoneAndPad() throws {
        launch()
        play("P3")
        capture("01-home")

        miniPlayer.tap()
        XCTAssertTrue(app.staticTexts["player.title"].waitForExistence(timeout: 20),
                      "the mini player did not open the full player")
        capture("02-player")

        app.buttons[text("Today's schedule", da: "Dagens sendeplan")].tap()
        XCTAssertTrue(app.staticTexts["Ny musik nu"].waitForExistence(timeout: 10),
                      "the schedule did not open")
        capture("03-schedule")

        launch(homeScope: "forYou")
        play("P3")
        XCTAssertTrue(app.staticTexts["Dagens samtale"].waitForExistence(timeout: 20),
                      "For you does not show the favourite shows")
        capture("04-for-you")

        // Search reads the programmes too: "musik" finds every station that plays it.
        launch()
        play("P3")
        app.tab(text("Search", da: "Søg")).tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Search has no field")
        field.tap()
        // Typed before the field has focus, the text went nowhere and Search stayed empty.
        // Focus, not the keyboard: with a hardware keyboard an iPad shows none.
        let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"),
                                  evaluatedWith: field)
        wait(for: [focused], timeout: 10)
        field.typeText("musik\n")
        let rows = app.descendants(matching: .any).matching(identifier: "search.row")
        XCTAssertTrue(rows.element(boundBy: 2).waitForExistence(timeout: 10),
                      "searching for \"musik\" found \(rows.count) stations, not five")
        capture("05-search")
    }
    #endif

    #if os(tvOS)
    /// Apple TV: Home, Now Playing, and the schedule over it.
    @MainActor
    func testAppleTV() throws {
        launch()
        XCTAssertTrue(focused.waitForExistence(timeout: 10), "nothing took focus on Home")
        XCTAssertTrue(moveFocus(.right, until: { $0.label.hasPrefix("P3") }), "could not reach P3")
        capture("01-home")

        press(.select)
        sleep(4)
        capture("02-now-playing")

        let schedule = text("Schedule", da: "Sendeplan")
        XCTAssertTrue(moveFocus(.right, until: { $0.label == schedule }),
                      "could not reach the schedule button; focus is on \(focusedLabel)")
        press(.select)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "schedule.row")
                          .firstMatch.waitForExistence(timeout: 5),
                      "the schedule did not open")
        sleep(1)
        capture("03-schedule")
    }
    #endif

    #if os(visionOS)
    /// Apple Vision Pro: Home with the mini player below it, the player, and *For you*.
    @MainActor
    func testVisionPro() throws {
        launch()
        play("P3")
        capture("01-home")

        miniPlayer.tap()
        XCTAssertTrue(app.staticTexts["player.title"].waitForExistence(timeout: 20),
                      "the mini player did not open the full player")
        capture("02-player")

        launch(homeScope: "forYou")
        play("P3")
        XCTAssertTrue(app.staticTexts["Dagens samtale"].waitForExistence(timeout: 20),
                      "For you does not show the favourite shows")
        capture("03-for-you")
    }
    #endif

    // MARK: - Helpers

    /// On the showcase, in the screenshot's language, with three favourite stations, five
    /// favourite shows and nothing playing, Copenhagen as the region.
    @MainActor
    private func launch(homeScope: String = "all") {
        app?.terminate()
        app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        app.launchEnvironment["LYTTER_UITEST_SHOWCASE"] = "1"
        app.launchEnvironment["LYTTER_UITEST_FAVOURITE_SHOWS"] = "5"
        let stations = ["p3", "p6", "p1"].map { "urn:fixture:\($0)" }
        app.launchArguments = [
            "-AppleLanguages", isDanish ? "(da)" : "(en)",
            "-AppleLocale", isDanish ? "da_DK" : "en_DK",
            "-homeScope", homeScope,
            "-favouriteChannelIDs", plistArray(stations),
            "-recentlyPlayedChannelIDs", plistArray(stations),
            "-recentSearchChannelIDs", "()",
            "-preferredDistrictName", "København",
            // Every key the last station is found by, so none is brought back.
            "-lastPlayedChannelId", "",
            "-lastPlayedChannelTitle", "",
            "-lastPlayedChannelName", "",
        ]
        app.launch()
        #if !os(tvOS)
        XCTAssertTrue(card("P1").waitForExistence(timeout: 20) || homeScope != "all",
                      "Home did not load")
        #endif
    }

    /// Asks the script for a screenshot named `name`, and waits until it has one.
    @MainActor
    private func capture(_ name: String) {
        // Sheets and focus animate in; let them land.
        sleep(2)
        let request = directory.appendingPathComponent("request")
        do {
            try name.write(to: request, atomically: true, encoding: .utf8)
        } catch {
            XCTFail("could not ask for \(name): \(error)")
            return
        }
        let deadline = Date().addingTimeInterval(60)
        while FileManager.default.fileExists(atPath: request.path), Date() < deadline {
            usleep(200_000)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: request.path),
                       "nothing took the screenshot \(name); is Tools/export-screenshots.sh running?")
    }

    @MainActor
    private func text(_ english: String, da danish: String) -> String {
        isDanish ? danish : english
    }

    @MainActor
    private func plistArray(_ values: [String]) -> String {
        "(" + values.map { "\"\($0)\"" }.joined(separator: ",") + ")"
    }

    #if !os(tvOS)
    /// A station's card on Home, by the station's name.
    @MainActor
    private func card(_ station: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND identifier != 'miniPlayer'",
                                         "\(station),")).firstMatch
    }

    @MainActor
    private var miniPlayer: XCUIElement { app.descendants(matching: .any)["miniPlayer"] }

    @MainActor
    private func play(_ station: String) {
        let card = card(station)
        XCTAssertTrue(card.waitForExistence(timeout: 20), "no \(station) on Home")
        card.tap()
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 10),
                      "playing \(station) did not bring up the mini player")
    }
    #endif

    #if os(tvOS)
    /// Presses `button` until the focused element satisfies `matches`, as
    /// `TVScrollingUITests` does.
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
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
    }

    @MainActor
    private var focusedLabel: String { focused.exists ? focused.label : "" }

    @MainActor
    private func press(_ button: XCUIRemote.Button) {
        XCUIRemote.shared.press(button)
        usleep(600_000)
    }
    #endif
}
