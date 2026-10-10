//
//  Pixels.swift
//  lytterUITests
//

import XCTest

#if os(iOS) || os(tvOS)
/// A screenshot as RGBA bytes, addressed in points.
struct Pixels {
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

    /// The average colour in `rect`, each channel 0–255.
    func averageColor(in rect: CGRect) -> (red: Int, green: Int, blue: Int) {
        let (xs, ys) = pixelRange(rect)
        var sums = [0, 0, 0], count = 0
        for y in ys {
            for x in xs {
                let i = (y * width + x) * 4
                sums[0] += Int(bytes[i]); sums[1] += Int(bytes[i + 1]); sums[2] += Int(bytes[i + 2])
                count += 1
            }
        }
        guard count > 0 else { return (0, 0, 0) }
        return (sums[0] / count, sums[1] / count, sums[2] / count)
    }

    /// How many pixels in `rect` differ from `other`'s by more than `threshold` in luminance.
    /// Text moving through the rect changes many. Two frames of still text over a blurred
    /// backdrop are not identical either, but they differ only faintly.
    func changedPixels(in rect: CGRect, from other: Pixels, threshold: Int = 40) -> Int {
        zip(crop(rect), other.crop(rect)).filter { abs($0 - $1) > threshold }.count
    }

    /// The spread of luminance in `rect`: near zero over plain background, large where
    /// text is drawn.
    func contrast(in rect: CGRect) -> Int {
        let values = crop(rect)
        guard let low = values.min(), let high = values.max() else { return 0 }
        return high - low
    }

    /// The height, in points, of what is drawn in `rect` against its background: the rows
    /// whose luminance stands more than `threshold` off the rect's own border. For a glyph
    /// in a frame larger than itself, that is the glyph's height.
    func inkHeight(in rect: CGRect, threshold: Int = 60) -> CGFloat {
        let (xs, ys) = pixelRange(rect)
        guard let x0 = xs.first, let x1 = xs.last, let y0 = ys.first, let y1 = ys.last else { return 0 }
        let border = xs.flatMap { [luminance(x: $0, y: y0), luminance(x: $0, y: y1)] }
            + ys.flatMap { [luminance(x: x0, y: $0), luminance(x: x1, y: $0)] }
        let background = border.sorted()[border.count / 2]
        let inked = ys.filter { y in xs.contains { abs(luminance(x: $0, y: y) - background) > threshold } }
        guard let top = inked.first, let bottom = inked.last else { return 0 }
        return CGFloat(bottom - top + 1) / scale
    }
}
#endif
