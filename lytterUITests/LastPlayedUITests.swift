//
//  LastPlayedUITests.swift
//  lytterUITests
//

import XCTest

#if os(iOS)
/// The mini player and the full player agree on the station last played, however long ago.
///
/// The mini player showed the last station whatever its age, but the station was loaded into
/// the player only within a day of being played — so after a day away the mini player said
/// "P2" and opened onto "No Channel Playing". Runs on fixtures (`UITestFixtures`), with the
/// last play two days old.
final class LastPlayedUITests: XCTestCase {

    @MainActor
    func testTheFullPlayerOpensOnAStationPlayedDaysAgo() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        let twoDaysAgo = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-2 * 86_400))
        // In the argument domain, read before the stored values and never written over them.
        app.launchArguments = [
            "-lastPlayedChannelId", "urn:fixture:p2",
            "-lastPlayedChannelTitle", "P2",
            "-lastPlayedChannelName", "P2",
            "-lastPlayedTimestamp", "<date>\(twoDaysAgo)</date>",
        ]
        app.launch()
        defer { app.terminate() }

        let miniPlayer = app.descendants(matching: .any)["miniPlayer"]
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 20), "no mini player")
        XCTAssertTrue(miniPlayer.label.hasPrefix("P2"),
                      "the mini player shows \"\(miniPlayer.label)\", not the last station")
        miniPlayer.tap()

        let title = app.staticTexts["player.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 20),
                      "the full player opened with no station: "
                      + "\(app.staticTexts["No Channel Playing"].exists ? "No Channel Playing" : "nothing")")
        XCTAssertTrue(title.label.hasPrefix("P2"), "the full player shows \"\(title.label)\"")
    }
}
#endif
