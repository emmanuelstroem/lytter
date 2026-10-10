//
//  TVNowPlayingUITests.swift
//  lytterUITests
//

import XCTest

#if os(tvOS)
/// Apple TV's Now Playing: how it dims when the remote is left alone, how every press brings
/// it back, and the track line that scrolls when it is long (B11).
///
/// This screen hid its controls once before and the remote could not get them back, except
/// with the back button; a direction press moved focus between buttons nobody could see.
/// So each of the remote's buttons is pressed here while the screen is dim, and each must
/// wake it and do nothing else — Play/Pause excepted, which also plays or pauses.
///
/// Runs on fixtures (`UITestFixtures`), with the idle delay cut short by
/// `LYTTER_UITEST_IDLE_SECONDS`. Without it the screen never dims under test.
final class TVNowPlayingUITests: XCTestCase {

    private var app: XCUIApplication!
    /// Longer than `openPlayer` takes to settle, so that the screen is lit when it returns.
    private static let idleSeconds = 6

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Left alone, the screen dims to the corner card, and nothing but the wake target can
    /// take focus.
    @MainActor
    func testNowPlayingDimsWhenLeftAlone() throws {
        launch()
        openPlayer()
        XCTAssertFalse(idleCard.exists, "the screen dimmed before it was left alone")
        XCTAssertTrue(schedule.exists, "the controls are not showing")
        shot("lit")

        XCTAssertTrue(idleCard.waitForExistence(timeout: TimeInterval(Self.idleSeconds + 4)),
                      "the screen did not dim")
        shot("dimmed")
        // The wake target has it, which is hidden from accessibility: no control does.
        XCTAssertEqual(focusedLabel, "", "while dim, focus is on \(focusedLabel)")
        XCTAssertFalse(schedule.isEnabled, "the controls can still be used while dim")
    }

    /// A direction press wakes the screen and hands focus back to the control that had it.
    /// It does not also move focus: the press was spent on waking. Each direction, since
    /// left has the sidebar beyond it. And focus has to be real afterwards — the remote has
    /// to move it — not only drawn.
    @MainActor
    func testADirectionPressWakesWithoutMovingFocus() throws {
        launch()
        openPlayer()
        XCTAssertTrue(moveFocus(.right, until: { $0.label == "Schedule" }),
                      "could not reach the schedule button; focus is on \(focusedLabel)")

        for (name, button) in [("up", XCUIRemote.Button.up), ("down", .down),
                               ("right", .right), ("left", .left)] {
            waitUntilDim()
            press(button)
            XCTAssertTrue(waitUntilLit(), "pressing \(name) did not wake the screen")
            sleep(1)
            XCTAssertEqual(focusedLabel, "Schedule", "waking with \(name) moved focus")
        }

        press(.left)
        XCTAssertNotEqual(focusedLabel, "Schedule", "after waking, the remote does not move focus")
        XCTAssertFalse(focusedLabel.isEmpty, "after waking, a press left nothing focused")
    }

    /// Select wakes the screen rather than pressing whatever had focus.
    @MainActor
    func testSelectWakesWithoutPressingAnything() throws {
        launch()
        openPlayer()
        XCTAssertTrue(moveFocus(.right, until: { $0.label == "Schedule" }),
                      "could not reach the schedule button; focus is on \(focusedLabel)")
        waitUntilDim()

        press(.select)
        XCTAssertTrue(waitUntilLit(), "select did not wake the screen")
        let rows = app.descendants(matching: .any).matching(identifier: "schedule.row")
        XCTAssertFalse(rows.firstMatch.waitForExistence(timeout: 2),
                       "select also opened the schedule")
    }

    /// Menu wakes the screen rather than leaving it; the next Menu goes back to Home.
    @MainActor
    func testMenuWakesBeforeItLeaves() throws {
        launch()
        openPlayer()
        waitUntilDim()

        press(.menu)
        XCTAssertTrue(waitUntilLit(), "Menu did not wake the screen")
        XCTAssertFalse(homeShelf.exists, "Menu left Now Playing instead of waking it")

        press(.menu)
        XCTAssertTrue(homeShelf.waitForExistence(timeout: 5),
                      "Menu did not go back to Home once awake")
    }

    /// Play/Pause wakes the screen. It also plays or pauses, which the fixtures cannot show:
    /// their streams never start. That the press reaches only the wake target's handler,
    /// and not the app's as well — which would toggle twice, and do nothing — was checked
    /// by logging both.
    @MainActor
    func testPlayPauseWakesTheScreen() throws {
        launch()
        openPlayer()
        waitUntilDim()

        XCUIRemote.shared.press(.playPause)
        XCTAssertTrue(waitUntilLit(), "Play/Pause did not wake the screen")
    }

    /// Not over a sheet: the schedule open for longer than the delay leaves the screen lit
    /// behind it, and lit when it closes.
    @MainActor
    func testTheScreenStaysLitUnderASheet() throws {
        launch()
        openPlayer()
        XCTAssertTrue(moveFocus(.right, until: { $0.label == "Schedule" }),
                      "could not reach the schedule button; focus is on \(focusedLabel)")
        press(.select)
        let rows = app.descendants(matching: .any).matching(identifier: "schedule.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5), "the schedule did not open")
        sleep(UInt32(Self.idleSeconds + 2))

        press(.menu)
        sleep(1)
        XCTAssertFalse(rows.firstMatch.exists, "the schedule did not close")
        XCTAssertFalse(idleCard.exists, "the screen dimmed while the schedule was open")
        XCTAssertTrue(schedule.isEnabled, "the controls are not usable after the schedule")
    }

    /// Skip back, skip forward and SharePlay are always on the row, and off when they have
    /// nothing to act on, so the row is the same on every station. They used to appear only
    /// when they could act, and read as gone. Under fixtures the stream never starts and
    /// there is no FaceTime call, so all three are there, and off.
    @MainActor
    func testTheRowKeepsControlsThatCannotAct() throws {
        launch()
        openPlayer()
        for label in ["Skip back 15 seconds", "Skip forward 15 seconds", "SharePlay"] {
            let button = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
            XCTAssertTrue(button.exists, "\(label) is not on the row")
            XCTAssertFalse(button.isEnabled, "\(label) can be used with nothing to act on")
        }
    }

    /// The schedule's focused row is drawn in the colour of the artwork on air. The fixtures
    /// have no artwork, so it is P2's own blue, which its placeholder artwork is drawn in;
    /// the faint white it used to be reads as grey on the panel.
    @MainActor
    func testTheSchedulesFocusedRowTakesTheArtworksColour() throws {
        launch()
        openPlayer()
        XCTAssertTrue(moveFocus(.right, until: { $0.label == "Schedule" }),
                      "could not reach the schedule button; focus is on \(focusedLabel)")
        press(.select)
        let rows = app.descendants(matching: .any).matching(identifier: "schedule.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5), "the schedule did not open")
        sleep(1)

        let row = focused.frame
        // A patch at the row's leading edge, inside the highlight and clear of the time.
        let patch = CGRect(x: row.minX + 4, y: row.midY - 4, width: 8, height: 8)
        let colour = Pixels(XCUIScreen.main.screenshot(), window: app.windows.firstMatch.frame)
            .averageColor(in: patch)
        XCTAssertGreaterThan(colour.blue - colour.red, 40,
                             "the focused row is not in P2's blue: \(colour)")
    }

    /// A track longer than the column scrolls through it (B11). It was one line ending in an
    /// ellipsis, and the end of the title was never shown. XCUITest reports a truncated
    /// line at its full label, so this reads the pixels.
    @MainActor
    func testALongTrackScrolls() throws {
        launch(longTitles: true)
        openPlayer()

        let track = app.descendants(matching: .any)["nowPlaying.track"]
        XCTAssertTrue(track.waitForExistence(timeout: 10), "no track line")
        XCTAssertTrue(track.label.hasPrefix("Christopher Rasmussen"),
                      "the track line is not the fixture's long track: \(track.label)")
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(window.contains(track.frame), "the track line reaches off screen: \(track.frame)")

        let before = Pixels(XCUIScreen.main.screenshot(), window: window)
        sleep(3)
        let after = Pixels(XCUIScreen.main.screenshot(), window: window)
        let changed = after.changedPixels(in: track.frame, from: before)
        XCTAssertGreaterThan(changed, 500, "the long track did not scroll")
    }

    // MARK: - Helpers

    @MainActor
    private func launch(longTitles: Bool = false) {
        app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        app.launchEnvironment["LYTTER_UITEST_IDLE_SECONDS"] = String(Self.idleSeconds)
        if longTitles { app.launchEnvironment["LYTTER_UITEST_LONG_TITLES"] = "1" }
        app.launchArguments = [
            "-favouriteChannelIDs", "()",
            "-recentlyPlayedChannelIDs", "()",
            "-preferredDistrictName", ""
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["DR"].waitForExistence(timeout: 15), "Home did not load")
        XCTAssertTrue(focused.waitForExistence(timeout: 10), "nothing took focus on Home")
    }

    /// Plays P2 from Home, which switches to Now Playing.
    @MainActor
    private func openPlayer() {
        XCTAssertTrue(moveFocus(.right, until: { $0.label.hasPrefix("P2") }), "could not reach P2")
        press(.select)
        XCTAssertTrue(schedule.waitForExistence(timeout: 10), "Now Playing did not open")
        sleep(2)
    }

    @MainActor
    private func waitUntilDim() {
        XCTAssertTrue(idleCard.waitForExistence(timeout: TimeInterval(Self.idleSeconds + 4)),
                      "the screen did not dim")
        sleep(1)
    }

    /// Whether the screen is lit within `timeout`: the corner card gone, and the controls
    /// there to use. While dim they are disabled but still in the tree.
    @MainActor
    private func waitUntilLit(timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if !idleCard.exists && schedule.exists && schedule.isEnabled { return true }
            usleep(200_000)
        } while Date() < deadline
        return false
    }

    @MainActor
    private var idleCard: XCUIElement { app.descendants(matching: .any)["nowPlaying.idle"] }

    @MainActor
    private var schedule: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == 'Schedule'")).firstMatch
    }

    /// Home's DR shelf heading. In a scroll view: the sidebar has a "DR" of its own.
    @MainActor
    private var homeShelf: XCUIElement { app.scrollViews.staticTexts["DR"] }

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
    private func press(_ button: XCUIRemote.Button) {
        XCUIRemote.shared.press(button)
        usleep(600_000)
    }

    @MainActor
    private var focused: XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "hasFocus == true")).firstMatch
    }

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
}
#endif
