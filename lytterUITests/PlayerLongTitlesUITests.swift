//
//  PlayerLongTitlesUITests.swift
//  lytterUITests
//

import XCTest

#if os(iOS)
/// Long titles in the full player scroll, and scroll inside their own column.
///
/// While a track plays the title line is the station and the programme, and it was a
/// one-line Text: on a smaller iPhone it ended in an ellipsis before the programme's name
/// began, and nothing would show the rest. The track line under it did scroll — out over the
/// 20pt margin, nearly to the edge of the screen.
///
/// Neither is visible to XCUITest, which reports a truncated Text at its full label and does
/// not know about masks, so this reads the pixels. Runs on fixtures with
/// `LYTTER_UITEST_LONG_TITLES`, which give every programme on air a title wider than any
/// phone and a track on air with an artist and title as long.
final class PlayerLongTitlesUITests: XCTestCase {

    @MainActor
    func testLongTitlesScrollWithinTheirColumn() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["LYTTER_UITEST_FIXTURES"] = "1"
        app.launchEnvironment["LYTTER_UITEST_LONG_TITLES"] = "1"
        app.launch()
        defer { app.terminate() }

        // Not the mini player, whose label also starts with the station once one is restored.
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH 'P1,' AND identifier != 'miniPlayer'"))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20), "no P1 card on Home")
        card.tap()
        let miniPlayer = app.descendants(matching: .any)["miniPlayer"]
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 20), "no mini player after playing P1")
        miniPlayer.tap()

        let title = app.staticTexts["player.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 20), "the full player did not open")
        // The fixture track is heard, so the title carries the programme.
        let heard = NSPredicate(format: "label CONTAINS 'Morgenhyrderne'")
        expectation(for: heard, evaluatedWith: title)
        waitForExpectations(timeout: 20)
        let track = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH 'Christopher Rasmussen'")).firstMatch
        XCTAssertTrue(track.exists, "no track line under the title")

        let titleFrame = title.frame
        let trackFrame = track.frame
        let window = app.windows.firstMatch.frame
        // The player's own bounds. On iPhone the sheet is the width of the screen; on iPad it
        // is centred, with Home dimmed on either side of it, and Home's text is not the
        // player's to keep out of its margin.
        let sheet = app.scrollViews["player.scroll"].frame
        // Each line is one element in its own frame, not the two copies of a scrolling text,
        // one of them far off the side of the player.
        for (name, frame) in [("title", titleFrame), ("track", trackFrame)] {
            XCTAssertTrue(sheet.contains(frame), "the \(name) reaches outside the player \(sheet): \(frame)")
        }

        // Scrolling starts 1.5 s after the text appears; take one frame either side of that.
        sleep(1)
        let before = Pixels(XCUIScreen.main.screenshot(), window: window)
        sleep(3)
        let after = Pixels(XCUIScreen.main.screenshot(), window: window)

        XCTAssertNotEqual(before.crop(titleFrame), after.crop(titleFrame),
                          "the title did not scroll")

        // The margin left of the column: from just inside the player's edge to just short of
        // where the title and track start. Nothing should be drawn there, at any point.
        let marginWidth = min(titleFrame.minX, trackFrame.minX) - 6 - (sheet.minX + 2)
        XCTAssertGreaterThan(marginWidth, 8, "no margin beside the title to check")
        let margin = CGRect(x: sheet.minX + 2, y: titleFrame.minY, width: marginWidth,
                            height: trackFrame.maxY - titleFrame.minY)
        for (moment, pixels) in [("before scrolling", before), ("while scrolling", after)] {
            XCTAssertLessThan(pixels.contrast(in: margin), 24,
                              "text drawn in the margin \(moment)")
        }
    }
}

/// A screenshot as RGBA bytes, addressed in points.
private struct Pixels {
    let width: Int
    let height: Int
    let scale: CGFloat
    let bytes: [UInt8]

    @MainActor
    init(_ screenshot: XCUIScreenshot, window: CGRect) {
        let image = screenshot.image.cgImage!
        width = image.width
        height = image.height
        scale = CGFloat(image.width) / window.width
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &bytes, width: width, height: height,
                                bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        self.bytes = bytes
    }

    private func luminance(x: Int, y: Int) -> Int {
        let i = (y * width + x) * 4
        return (Int(bytes[i]) * 299 + Int(bytes[i + 1]) * 587 + Int(bytes[i + 2]) * 114) / 1000
    }

    private func pixelRange(_ rect: CGRect) -> (xs: Range<Int>, ys: Range<Int>) {
        let x0 = max(Int(rect.minX * scale), 0), x1 = min(Int(rect.maxX * scale), width)
        let y0 = max(Int(rect.minY * scale), 0), y1 = min(Int(rect.maxY * scale), height)
        return (x0..<max(x0, x1), y0..<max(y0, y1))
    }

    /// The luminance of every pixel in `rect`, row by row.
    func crop(_ rect: CGRect) -> [Int] {
        let (xs, ys) = pixelRange(rect)
        return ys.flatMap { y in xs.map { x in luminance(x: x, y: y) } }
    }

    /// The spread of luminance in `rect`: near zero over plain background, large where
    /// text is drawn.
    func contrast(in rect: CGRect) -> Int {
        let values = crop(rect)
        guard let low = values.min(), let high = values.max() else { return 0 }
        return high - low
    }
}
#endif
