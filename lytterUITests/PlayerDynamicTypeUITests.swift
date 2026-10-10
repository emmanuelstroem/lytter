//
//  PlayerDynamicTypeUITests.swift
//  lytterUITests
//

import XCTest

#if os(iOS)
/// The full player's text follows Dynamic Type (F11b).
///
/// The station and track were sized as a share of a GeometryReader's frame, so at the largest
/// text sizes they stayed small while the progress row beneath them grew. Runs on fixtures
/// (`UITestFixtures`), so there is always a station to open.
final class PlayerDynamicTypeUITests: XCTestCase {

    @MainActor
    func testPlayerTitleGrowsWithTheTextSize() throws {
        continueAfterFailure = false
        let regular = try titleHeight(contentSize: "UICTContentSizeCategoryL")
        let large = try titleHeight(contentSize: "UICTContentSizeCategoryAccessibilityXL")
        XCTAssertGreaterThan(large, regular * 1.5,
                             "the player title is \(large)pt tall at AX3 against \(regular)pt by default")
    }

    /// Opens the full player at `contentSize` and returns the station title's height.
    @MainActor
    private func titleHeight(contentSize: String) throws -> CGFloat {
        let app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", contentSize]
        app.launch()
        defer { app.terminate() }

        // Not the mini player, whose label also starts with the station once one is restored.
        // On iPhone tapping it twice was harmless, the sheet covering it by the second tap;
        // on iPad the sheet is centred, the mini player stays in reach, and the second tap
        // landed outside the sheet and closed it.
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH 'P1,' AND identifier != 'miniPlayer'"))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20), "no P1 card on Home")
        // A card plays the station; the full player opens from the mini player, as a
        // listener opens it.
        card.tap()
        let miniPlayer = app.descendants(matching: .any)["miniPlayer"]
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 20), "no mini player after playing P1")
        miniPlayer.tap()

        let title = app.staticTexts["player.title"]
        // Generous: the first launch after a build can take a while to present the sheet.
        XCTAssertTrue(title.waitForExistence(timeout: 20), "the full player did not open")
        return title.frame.height
    }
}
#endif
