//
//  TVCardCaptionUITests.swift
//  lytterUITests
//

import XCTest

#if os(tvOS)
/// The programme printed under a card on Apple TV is set at the platform's reading size.
///
/// It was sized from the card, like the station's name on it, and came to 20 points: below
/// the system's own caption size, small print from across a room. XCUITest does not report
/// a font, so this measures how tall the drawn text is. Runs on fixtures (`UITestFixtures`),
/// whose programme names are long enough to take both of the caption's lines.
final class TVCardCaptionUITests: XCTestCase {

    @MainActor
    func testTheProgrammeUnderACardIsSetAtReadingSize() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        app.launchArguments = [
            "-favouriteChannelIDs", "()",
            "-recentlyPlayedChannelIDs", "()",
            "-preferredDistrictName", ""
        ]
        app.launch()

        // Outside the card's button, so a text of its own; the caption on the artwork is
        // part of the button's label.
        let caption = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS 'Fixture'")).firstMatch
        XCTAssertTrue(caption.waitForExistence(timeout: 15), "no programme under a card")
        sleep(1)

        let window = app.windows.firstMatch.frame
        XCTAssertTrue(window.contains(caption.frame), "the caption is off screen: \(caption.frame)")
        let ink = Pixels(XCUIScreen.main.screenshot(), window: window).inkHeight(in: caption.frame)
        // One line at the old 20 points draws about 19 points of ink, descenders and all;
        // a line at the reading size, 29, draws more than 24 on its own.
        XCTAssertGreaterThan(ink, 24, "the programme under the card is drawn \(ink) points tall")
    }
}
#endif
