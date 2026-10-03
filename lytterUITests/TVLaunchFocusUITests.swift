//
//  TVLaunchFocusUITests.swift
//  lytterUITests
//

import XCTest

#if os(tvOS)
/// The app opens on its content, sidebar closed, as the TV and Music apps do (F34).
///
/// Left to the system, launch focus went to the sidebar's selected entry, which opens the
/// sidebar over the shelves; the system moved focus into the content only some seconds
/// later. Runs on fixtures (`UITestFixtures`), so Home always has cards.
final class TVLaunchFocusUITests: XCTestCase {

    @MainActor
    func testLaunchFocusIsOnTheFirstCardNotTheSidebar() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        // No favourites, so the first shelf is Recently Played, starting with P3.
        app.launchArguments = [
            "-favouriteChannelIDs", "()",
            "-recentlyPlayedChannelIDs", "(\"urn:fixture:p3\")",
            "-preferredDistrictName", ""
        ]
        app.launch()

        let focused = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hasFocus == true")).firstMatch
        XCTAssertTrue(focused.waitForExistence(timeout: 15), "nothing took focus on Home")
        // Sample over the first seconds: the bug was focus sitting in the sidebar until the
        // system moved it, so one early look could pass by luck either way.
        for _ in 0..<3 {
            XCTAssertTrue(focused.label.hasPrefix("P3"),
                          "launch focus is on '\(focused.label)', not the first card")
            sleep(1)
        }
    }
}
#endif
