//
//  PlayerIconsDynamicTypeUITests.swift
//  lytterUITests
//

import XCTest

#if os(iOS)
/// The players' controls follow Dynamic Type, as their text does.
///
/// The mini player's play button was a fixed 16pt glyph, and the full player's action icons
/// a share of their row's height, so at the larger text sizes the words grew past the
/// controls beside them. Each glyph sits in a frame that does not change with it (a 32pt
/// button, a 44pt target), so XCUITest's frames cannot show this; it reads the pixels.
/// Runs on fixtures (`UITestFixtures`), so there is always a station to play.
final class PlayerIconsDynamicTypeUITests: XCTestCase {

    @MainActor
    func testTheControlsGrowWithTheTextSize() throws {
        continueAfterFailure = false
        let regular = glyphHeights(contentSize: "UICTContentSizeCategoryL")
        let large = glyphHeights(contentSize: "UICTContentSizeCategoryAccessibilityXL")
        // 16 to 21pt for the mini player, where its bar stops growing; 17 to 28pt for the
        // full player's, capped at the first accessibility size. Measured, the glyphs' ink
        // grows by a quarter and by two thirds.
        XCTAssertGreaterThan(large.miniPlayer, regular.miniPlayer * 1.15,
                             "the mini player's play button is \(large.miniPlayer)pt at AX3 against \(regular.miniPlayer)pt by default")
        XCTAssertGreaterThan(large.sleep, regular.sleep * 1.4,
                             "the sleep timer is \(large.sleep)pt at AX3 against \(regular.sleep)pt by default")
    }

    /// Plays P1 at `contentSize`, measures the mini player's play button, then opens the full
    /// player from it and measures the sleep timer.
    @MainActor
    private func glyphHeights(contentSize: String) -> (miniPlayer: CGFloat, sleep: CGFloat) {
        let app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", contentSize]
        app.launch()
        defer { app.terminate() }

        // Not the mini player, whose label also starts with the station once one is restored.
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH 'P1,' AND identifier != 'miniPlayer'"))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20), "no P1 card on Home")
        card.tap()
        // The fixtures' stream never starts, so the button stays on Play, at every size.
        let playPause = app.buttons["miniPlayer.playPause"]
        XCTAssertTrue(playPause.waitForExistence(timeout: 20), "no mini player after choosing P1")
        sleep(1)  // the bar settles as it takes the station
        let window = app.windows.firstMatch.frame
        // Each frame read before its screenshot, so the two describe the same moment.
        let playPauseFrame = playPause.frame
        let miniPlayer = Pixels(XCUIScreen.main.screenshot(), window: window)
            .inkHeight(in: playPauseFrame)

        app.descendants(matching: .any)["miniPlayer"].tap()
        let sleepTimer = app.buttons["player.sleep"]
        XCTAssertTrue(sleepTimer.waitForExistence(timeout: 20), "the full player did not open")
        sleep(1)  // the sheet finishes rising: on its way up, everything in it is "hittable"
        // At the largest sizes the player outgrows a small screen and scrolls (#108).
        let inView = { sleepTimer.isHittable && window.contains(sleepTimer.frame) }
        for _ in 0..<3 where !inView() {
            app.scrollViews["player.scroll"].swipeUp()
            sleep(1)  // the scroll settles
        }
        let sleepFrame = sleepTimer.frame
        XCTAssertTrue(window.contains(sleepFrame), "the sleep timer never came into view: \(sleepFrame)")
        let player = Pixels(XCUIScreen.main.screenshot(), window: window)
        return (miniPlayer, player.inkHeight(in: sleepFrame))
    }
}
#endif
