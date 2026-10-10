//
//  StationCardDynamicTypeUITests.swift
//  lytterUITests
//

import XCTest

#if os(iOS)
/// The programme's name under a station's card follows Dynamic Type, and at the
/// accessibility sizes wraps rather than truncating to a word.
///
/// It was one line at every size, so at the accessibility sizes it read "Fixtur…". Runs on
/// fixtures (`UITestFixtures`), whose programme on air, "Fixture: Et langt program", is
/// longer than a card is wide at those sizes.
final class StationCardDynamicTypeUITests: XCTestCase {

    @MainActor
    func testTheProgrammeWrapsAtTheAccessibilitySizes() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        // On All, where every station is a standard card with its programme beneath it.
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL",
                               "-homeScope", "all"]
        app.launch()
        defer { app.terminate() }

        // Not the mini player, whose label also starts with the station once one is restored.
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH 'P3,' AND identifier != 'miniPlayer'"))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20), "no P3 card on Home")

        // The card's button is the tile, 148pt square, then 6pt, then the programme.
        let caption = card.frame.height - 148 - 6
        // The caption's size at AX3: the card's 11pt, scaled as caption2 is.
        let fontSize = UIFontMetrics(forTextStyle: .caption2)
            .scaledValue(for: 11, compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraLarge))
        XCTAssertGreaterThan(caption, fontSize * 1.8,
                             "the programme is \(caption)pt tall at \(fontSize)pt: one line, truncated")
    }
}
#endif
