//
//  DefaultArtworkTests.swift
//  lytterTests
//

import Testing
import Foundation
import CoreGraphics
@testable import lytter

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The fallback now-playing artwork: the brand mark, the same on every platform.
///
/// @MainActor because the project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct DefaultArtworkTests {

    /// The icon's square: red field at the edge, the white radio body at the centre. Not a
    /// blank image, which is what a missing or renamed asset falls back to.
    @Test func isTheBrandMark() throws {
        let image = AudioPlayerService.defaultArtworkImage()
        #expect(image.size == CGSize(width: 300, height: 300))
        let cg = try #require(Self.cgImage(image))

        let field = try #require(Self.pixel(cg, x: 0.04, y: 0.04))
        #expect(field.a > 0.99)
        #expect(field.r > 0.7 && field.g < 0.35 && field.b < 0.25, "field is \(field)")

        let body = try #require(Self.pixel(cg, x: 0.5, y: 0.5))
        #expect(body.r > 0.85 && body.g > 0.85 && body.b > 0.85, "centre is \(body)")
    }

    #if os(macOS)
    /// It has to survive being rendered off the main thread.
    ///
    /// MediaPlayer turns now-playing artwork into JPEG data on its own queue. The Mac's image
    /// was once drawn by a handler that ran then, main-actor isolated by the project's
    /// default, and Swift's isolation check trapped: the app died as it opened, and so did
    /// this test target's host.
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
    }
    #endif

    // MARK: - Pixels

    private static func cgImage(_ image: PlatformImage) -> CGImage? {
        #if os(macOS)
        image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        image.cgImage
        #endif
    }

    /// The colour at a point given as fractions of the width and height, read by drawing
    /// the image into an RGBA bitmap of known layout.
    private static func pixel(_ image: CGImage, x: Double, y: Double)
        -> (r: Double, g: Double, b: Double, a: Double)? {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        let i = (Int(y * Double(height - 1)) * width + Int(x * Double(width - 1))) * 4
        return (Double(bytes[i]) / 255, Double(bytes[i + 1]) / 255,
                Double(bytes[i + 2]) / 255, Double(bytes[i + 3]) / 255)
    }
}
