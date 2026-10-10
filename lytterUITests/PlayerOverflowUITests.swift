//
//  PlayerOverflowUITests.swift
//  lytterUITests
//

import XCTest

#if os(iOS)
/// The full player is fixed when it fits and scrolls when it does not (B1).
///
/// At the largest text sizes on an iPhone SE, with the connection banner up, the rows below
/// the artwork need more than the screen's height. They were centred in what they were
/// given, so they spilled upwards past the 40pt top inset and the banner ran over the grab
/// handle. On fixtures the banner is always up in the player: the fixture stream never plays.
final class PlayerOverflowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// At Accessibility XL the banner stays clear of the top inset, and the rows that do not
    /// fit are a scroll away rather than off the screen.
    @MainActor
    func testTheBannerStaysBelowTheGrabHandleAtTheLargestSizes() throws {
        let app = try openPlayer(contentSize: "UICTContentSizeCategoryAccessibilityXL")
        let scroll = app.scrollViews["player.scroll"]
        let banner = bannerText(app)

        // The banner's text is its padding, 12pt, inside the banner.
        let bannerTop = banner.frame.minY - 12
        XCTAssertGreaterThanOrEqual(bannerTop, scroll.frame.minY + 40 - 2,
                                    "the banner's top, \(Int(bannerTop - scroll.frame.minY))pt into the player, runs into its 40pt top inset")

        // Scrolled to, not hittable: XCUITest calls a button in a scroll view hittable
        // while it is still half off the screen.
        let sleep = app.buttons["Sleep timer"]
        let bottom = app.windows.firstMatch.frame.maxY
        for _ in 0..<5 where sleep.frame.maxY > bottom { scroll.swipeUp() }
        XCTAssertLessThanOrEqual(sleep.frame.maxY, bottom,
                                 "the actions row cannot be scrolled onto the screen")
    }

    /// At the default size everything fits, and the player does not move under a swipe.
    @MainActor
    func testThePlayerDoesNotScrollWhenItFits() throws {
        let app = try openPlayer(contentSize: "UICTContentSizeCategoryL")
        let title = app.staticTexts["player.title"]
        let before = title.frame.minY

        app.scrollViews["player.scroll"].swipeUp()
        XCTAssertEqual(title.frame.minY, before, accuracy: 1,
                       "the player scrolled although everything fits")
    }

    /// Opens the full player on P1 at `contentSize`, as a listener does: the card, then
    /// the mini player.
    @MainActor
    private func openPlayer(contentSize: String) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", contentSize]
        app.launch()
        addTeardownBlock { app.terminate() }

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
        XCTAssertTrue(bannerText(app).waitForExistence(timeout: 20),
                      "no connection banner in the player")
        return app
    }

    /// The banner's title and message, one element. Whichever problem the fixtures give.
    @MainActor
    private func bannerText(_ app: XCUIApplication) -> XCUIElement {
        app.scrollViews["player.scroll"].descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@",
                                  "Couldn't play", "You're offline"))
            .firstMatch
    }
}
#endif
