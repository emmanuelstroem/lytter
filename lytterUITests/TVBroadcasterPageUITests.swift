//
//  TVBroadcasterPageUITests.swift
//  lytterUITests
//

import XCTest

#if os(tvOS)
/// A broadcaster's page in the sidebar is its shelf on Home, on a page of its own: the same
/// heading, the same cards, in the same places.
///
/// It was built separately and drifted. Its heading was larger, and it ignored the screen's
/// horizontal safe area, so its heading and cards sat 80 points further left than Home's,
/// close to the edge of the screen. Runs on fixtures (`UITestFixtures`) with nothing
/// favourited or played, so DR is Home's first shelf and the two can be laid side by side.
final class TVBroadcasterPageUITests: XCTestCase {

    private var app: XCUIApplication!

    @MainActor
    func testABroadcastersPageLooksLikeItsShelfOnHome() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        app.launchArguments = [
            "-favouriteChannelIDs", "()",
            "-recentlyPlayedChannelIDs", "()",
            "-preferredDistrictName", ""
        ]
        app.launch()
        XCTAssertTrue(heading.waitForExistence(timeout: 15), "Home has no DR shelf")
        XCTAssertTrue(focused.waitForExistence(timeout: 10), "nothing took focus on Home")
        sleep(1)
        // P2 rather than P1: P1 has focus on both screens, and the lift of a focused card
        // would be compared too.
        let onHome = (heading: heading.frame, card: card("P2").frame)

        openSection("DR")
        XCTAssertTrue(heading.waitForExistence(timeout: 5), "the DR page has no heading")
        sleep(1)
        let onPage = (heading: heading.frame, card: card("P2").frame)

        assertSame(onPage.heading, onHome.heading, "the heading")
        assertSame(onPage.card, onHome.card, "P2's card")
    }

    // MARK: - Helpers

    @MainActor
    private func assertSame(_ page: CGRect, _ home: CGRect, _ what: String,
                            file: StaticString = #filePath, line: UInt = #line) {
        let close = abs(page.minX - home.minX) <= 1 && abs(page.minY - home.minY) <= 1
            && abs(page.width - home.width) <= 1 && abs(page.height - home.height) <= 1
        XCTAssertTrue(close, "\(what) is at \(page) on the DR page and \(home) on Home",
                      file: file, line: line)
    }

    /// The shelf's own heading, not the sidebar's DR entry.
    @MainActor
    private var heading: XCUIElement {
        app.staticTexts.matching(identifier: "shelf.title")
            .matching(NSPredicate(format: "label == 'DR'")).firstMatch
    }

    @MainActor
    private func card(_ station: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(station),")).firstMatch
    }

    /// Opens a sidebar destination: left into the sidebar, up to its top, then down to it.
    @MainActor
    private func openSection(_ name: String) {
        let destinations = ["Search", "Home", "DR", "Now Playing", "Settings"]
        XCTAssertTrue(moveFocus(.left, until: { destinations.contains($0.label) }, maxPresses: 8),
                      "could not move into the sidebar; focus is on \(focusedLabel)")
        moveFocus(.up, until: { $0.label == "Search" }, maxPresses: 6)
        XCTAssertTrue(moveFocus(.down, until: { $0.label == name }, maxPresses: 6),
                      "could not find \(name) in the sidebar; focus is on \(focusedLabel)")
        press(.select)
        sleep(2)
        if destinations.contains(focusedLabel) { press(.right) }
    }

    @MainActor
    @discardableResult
    private func moveFocus(_ button: XCUIRemote.Button, until matches: (XCUIElement) -> Bool,
                           maxPresses: Int = 12) -> Bool {
        for _ in 0..<maxPresses {
            if focused.exists && matches(focused) { return true }
            press(button)
        }
        return focused.exists && matches(focused)
    }

    @MainActor
    private func press(_ button: XCUIRemote.Button) {
        XCUIRemote.shared.press(button)
        usleep(600_000)
    }

    @MainActor
    private var focused: XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
    }

    @MainActor
    private var focusedLabel: String { focused.exists ? focused.label : "" }
}
#endif
