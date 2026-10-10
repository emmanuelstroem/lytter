//
//  ConnectionBannerDynamicTypeUITests.swift
//  lytterUITests
//

import XCTest

#if os(iOS) || os(visionOS)
/// The connection banner stacks Try Again under its text at accessibility sizes (B3).
///
/// It was one row — icon, text, Try Again — and at Accessibility XL the row was too narrow
/// for it: the title truncated to "Could…" and the button wrapped mid-word, "Try Agai / n".
/// XCUITest reports a truncated Text at its full label, so this checks where the button
/// sits rather than reading the words. Runs on Home, offline over cached fixtures, where the
/// banner is up over the channels.
final class ConnectionBannerDynamicTypeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTryAgainSitsUnderTheTextAtAccessibilitySizes() throws {
        let (text, button) = try banner(contentSize: "UICTContentSizeCategoryAccessibilityXL")
        XCTAssertGreaterThanOrEqual(button.minY, text.maxY - 1,
                                    "Try Again \(button) sits beside the text \(text), not under it")
        XCTAssertLessThan(abs(button.minX - text.minX), 2,
                          "Try Again \(button) is not in the text's column \(text)")
    }

    /// The default size keeps the one row: the stacking is for when the row cannot fit.
    @MainActor
    func testTryAgainSitsBesideTheTextByDefault() throws {
        let (text, button) = try banner(contentSize: "UICTContentSizeCategoryL")
        XCTAssertGreaterThan(button.minX, text.maxX,
                             "Try Again \(button) is not beside the text \(text)")
    }

    /// Launches Home at `contentSize`, offline over the cached fixtures, and returns the
    /// frames of the banner's text and its Try Again button.
    @MainActor
    private func banner(contentSize: String) throws -> (text: CGRect, button: CGRect) {
        let app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        app.launchEnvironment["LYTTER_UITEST_NETWORK"] = "offline-cached"
        app.launchArguments = [
            "-UIPreferredContentSizeCategoryName", contentSize,
            "-favouriteChannelIDs", "()", "-recentlyPlayedChannelIDs", "()",
        ]
        app.launch()
        addTeardownBlock { app.terminate() }

        // The title and the message are one element, read together.
        let text = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "You're offline")).firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 20), "no connection banner on Home")
        let button = app.buttons["Try Again"]
        XCTAssertTrue(button.exists, "the banner has no Try Again")
        return (text.frame, button.frame)
    }
}
#endif
