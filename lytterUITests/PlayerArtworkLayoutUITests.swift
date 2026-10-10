//
//  PlayerArtworkLayoutUITests.swift
//  lytterUITests
//

import XCTest

#if os(iOS)
/// The full player's artwork takes the room the rows below it do not need.
///
/// The artwork and everything under it used to split the height evenly. On a shorter iPhone
/// the lower half needs more than half, and its rows and fixed 30pt gaps came out of the
/// artwork: on an iPhone SE it shrank to under a third of the width, while 77pt stood empty
/// between the progress bar and the play button.
///
/// So the gap above the play button must be at its floor (24pt, plus the play row's own
/// margin): any more is room the artwork should have had. The one exception is an artwork
/// already at its largest, a square nearly as wide as the screen, with height to spare — but
/// on fixtures the connection banner is always up (the fixture stream never plays), and with
/// it there is no height to spare on any iPhone from the SE to the Pro Max.
final class PlayerArtworkLayoutUITests: XCTestCase {

    @MainActor
    func testTheArtworkLeavesNoSpareRoomBelowIt() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        app.launch()
        defer { app.terminate() }

        let window = app.windows.firstMatch.frame
        if window.width > 500 { throw XCTSkip("a phone's layout; this is wider than any phone") }

        // Not the mini player, whose label also starts with the station once one is restored.
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH 'P1,' AND identifier != 'miniPlayer'"))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20), "no P1 card on Home")
        card.tap()
        let miniPlayer = app.descendants(matching: .any)["miniPlayer"]
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 20), "no mini player after playing P1")
        miniPlayer.tap()
        XCTAssertTrue(app.staticTexts["player.title"].waitForExistence(timeout: 20),
                      "the full player did not open")

        let live = app.staticTexts["LIVE"]
        // The full player's play button, not the mini player's behind the sheet.
        let play = app.buttons.matching(NSPredicate(format: "label == 'Play'"))
            .allElementsBoundByIndex.max { $0.frame.height < $1.frame.height }
        XCTAssertTrue(live.exists, "no progress row")
        let playFrame = try XCTUnwrap(play?.frame, "no play button")

        let gap = playFrame.minY - live.frame.maxY
        XCTAssertLessThan(gap, 40,
                          "\(Int(gap))pt stands empty above the play button, taken from the artwork")
    }
}
#endif
