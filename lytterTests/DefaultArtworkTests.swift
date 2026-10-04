//
//  DefaultArtworkTests.swift
//  lytterTests
//

import Testing
import Foundation
@testable import lytter

#if os(macOS)
import AppKit

/// The fallback now-playing artwork has to survive being rendered off the main thread.
///
/// MediaPlayer turns now-playing artwork into JPEG data on its own queue. The Mac's image was
/// drawn by a handler that ran then, main-actor isolated by the project's default, and Swift's
/// isolation check trapped: the app died as it opened, and so did this test target's host.
///
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct DefaultArtworkTests {

    @Test func rendersOffTheMainThread() async {
        let image = AudioPlayerService.defaultArtworkImage()
        // As MediaPlayer does: another queue asking for the pixels. `async`, not `sync`:
        // a `sync` from the main thread runs its block on the main thread, and passed.
        let data = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: image.tiffRepresentation)
            }
        }
        #expect(data != nil)
        #expect(image.size == NSSize(width: 300, height: 300))
    }

    /// Drawn, not blank: the middle of a blue-to-purple gradient has colour in it.
    @Test func isTheGradient() throws {
        let image = AudioPlayerService.defaultArtworkImage()
        let bitmap = try #require(image.representations.first as? NSBitmapImageRep)
        let middle = try #require(bitmap.colorAt(x: 150, y: 150))
        #expect(middle.alphaComponent > 0.99)
        #expect(middle.blueComponent > 0.5)
    }
}
#endif
