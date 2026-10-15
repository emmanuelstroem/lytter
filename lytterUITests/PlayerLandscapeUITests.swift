//
//  PlayerLandscapeUITests.swift
//  lytterUITests
//

import XCTest

#if os(iOS)
/// On its side, an iPhone's full player puts the artwork beside the controls, as Music does.
///
/// The player was laid out for portrait alone: the artwork took whatever height the rows
/// under it did not need, and an iPhone in landscape has none to spare. The artwork shrank
/// to nothing, and the rows still ran past the bottom, so the player scrolled.
///
/// The artwork is measured by the room the column beside it leaves. It is hidden from
/// VoiceOver, being decoration (on fixtures, a station-name tile), and in landscape a
/// screenshot's pixels stay in the upright framebuffer while the elements' frames turn, so
/// neither the accessibility tree nor `Pixels` can find it.
final class PlayerLandscapeUITests: XCTestCase {

    @MainActor
    func testTheArtworkSitsBesideTheControlsInLandscape() throws {
        continueAfterFailure = false
        // Upright again afterwards: the simulator keeps its orientation for whatever runs next.
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .landscapeLeft

        let app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        addTeardownBlock { app.terminate() }

        let window = app.windows.firstMatch.frame
        if window.height > 500 { throw XCTSkip("a phone on its side; this is taller than any") }
        XCTAssertGreaterThan(window.width, window.height, "the app did not turn to landscape")

        // Not the mini player, whose label also starts with the station once one is restored.
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH 'P1,' AND identifier != 'miniPlayer'"))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20), "no P1 card on Home")
        card.tap()
        let miniPlayer = app.descendants(matching: .any)["miniPlayer"]
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 20), "no mini player after playing P1")
        miniPlayer.tap()

        let title = app.staticTexts["player.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 20), "the full player did not open")
        let scroll = app.scrollViews["player.scroll"]
        let player = scroll.frame
        // The full player's play button, not the mini player's behind the sheet.
        let play = try XCTUnwrap(app.buttons.matching(NSPredicate(format: "label == 'Play'"))
            .allElementsBoundByIndex.max { $0.frame.height < $1.frame.height }, "no play button")
        let sleep = app.buttons["Sleep timer"]
        XCTAssertTrue(sleep.exists, "no actions row")

        // Beside it, not under it: the column starts clear of a square most of the player's
        // height, and the controls sit right of the middle.
        let artworkRoom = title.frame.minX - player.minX
        XCTAssertGreaterThan(artworkRoom, player.height * 0.6,
                             "\(Int(artworkRoom))pt beside the column, in a player \(Int(player.height))pt tall: no room for the artwork")
        XCTAssertGreaterThan(play.frame.midX, player.midX, "the controls are not beside the artwork")

        // All of it on the screen at the default size, and still under a swipe.
        XCTAssertLessThanOrEqual(sleep.frame.maxY, window.maxY, "the actions row runs off the screen")
        let before = title.frame.minY
        scroll.swipeUp()
        XCTAssertEqual(title.frame.minY, before, accuracy: 1,
                       "the player scrolled although everything fits")

        // Upright again, the same column is back under the artwork.
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 1)
        let upright = scroll.frame
        XCTAssertLessThan(title.frame.minX - upright.minX, 40,
                          "the column stayed beside the artwork with the phone upright")
        XCTAssertGreaterThan(title.frame.minY - upright.minY, upright.width * 0.6,
                             "no room above the column for the artwork with the phone upright")
    }
}
#endif
