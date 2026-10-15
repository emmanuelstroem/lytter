//
//  lytterUITestsLaunchTests.swift
//  lytterUITests
//
//  Created by Emmanuel on 07/08/2025.
//

import XCTest

final class lytterUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        #if os(iOS)
        // Upright again afterwards. This runs once in each orientation, landscape last, and
        // left the simulator on its side: whatever test ran next on it opened the app in
        // landscape, where the player scrolls and a screenshot's pixels no longer line up
        // with the elements' frames. In parallel that was whichever class came next on this
        // clone, so the player's tests failed only when the whole suite ran.
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        #endif
        let app = XCUIApplication()
        app.launch()

        #if os(visionOS)
        // No screenshot: the visionOS simulator cannot take one (*remote interface does not
        // have this capability*), and asking failed this test once for each of its launch
        // configurations (B12). That the app comes up is still checked; what it draws is
        // VisionLaunchUITests'.
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10),
                      "the app did not come to the front")
        #else
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
        #endif
    }
}
