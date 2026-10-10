//
//  AccessibilityAuditUITests.swift
//  lytterUITests
//

import XCTest

#if os(iOS)
/// The system's accessibility audit over the main iPhone screens (F11).
///
/// Limited to what the audit judges reliably here: hit targets, and every element having a
/// description. Left out on purpose:
/// - contrast, which flagged full-strength white text on the near-black sheet;
/// - Dynamic Type and clipped text, which flag the station name on a card's artwork (fixed
///   by design, sized so every name fits) and single-line programme names that truncate.
/// The player's action icons failed the hit-target check at 19pt before they got 44pt frames.
final class AccessibilityAuditUITests: XCTestCase {

    @MainActor
    func testMainScreensPassTheAudit() throws {
        let app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        // On All, where every station is (F54c), whatever chip the simulator last had.
        app.launchArguments = ["-homeScope", "all"]
        app.launch()
        // Not the mini player, whose label also starts with the station once one is restored.
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH 'P1,' AND identifier != 'miniPlayer'"))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20), "Home did not load")

        try audit(app)                                  // Home, on All: chips and every station
        // Settings before Search: in search mode the tab bar folds away its other tabs.
        app.tab("Settings").tap()
        try audit(app)
        app.tab("Search").tap()
        try audit(app)

        // On iPhone, in search mode the bar folds to one button, the tab that was open before
        // Search; that brings the full bar back, and Home is then named rather than counted.
        // iPad's tabs at the top of the window stay as they are.
        if !app.tab("Home").exists { app.tabBars.buttons.element(boundBy: 0).tap() }
        app.tab("Home").tap()
        card.tap()                                      // plays P1
        // Then the full player, from the mini player. Tapping a card does not open it; this
        // used to pass only when P1 was already the last station played, which made the
        // mini player the first element labelled "P1" and the one the tap above landed on.
        let miniPlayer = app.descendants(matching: .any)["miniPlayer"]
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 10), "no mini player")
        miniPlayer.tap()
        XCTAssertTrue(app.staticTexts["player.title"].waitForExistence(timeout: 20),
                      "the full player did not open")
        try audit(app)
    }

    @MainActor
    private func audit(_ app: XCUIApplication) throws {
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription])
    }
}
#endif
