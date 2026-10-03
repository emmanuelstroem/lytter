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
        app.launch()
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'P1'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20), "Home did not load")

        try audit(app)                                  // Home
        app.tabBars.buttons["Radio"].tap()
        try audit(app)
        app.tabBars.buttons["Search"].tap()
        try audit(app)

        app.tabBars.buttons.element(boundBy: 0).tap()
        card.tap()                                      // the full player
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
