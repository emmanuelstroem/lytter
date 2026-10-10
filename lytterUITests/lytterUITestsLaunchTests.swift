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
