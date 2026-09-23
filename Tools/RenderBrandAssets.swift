// RenderBrand.swift — generates the tvOS Brand Assets for Lytter.
//
// The mark is the same transistor radio as the iOS icon (AppIcon.icon): orange-red
// body, diagonal antenna, two cream bars and a dial. It is defined here in a unit
// square so it stays vector-exact at every size rather than being upscaled.
//
// The icon is split Back / Middle / Front for the tvOS parallax stack:
//   Back   full-bleed, opaque field — must fill the frame, it is revealed at the
//          edges as the layers shift on focus
//   Middle the antenna and the body — the mass of the object
//   Front  the bars and the dial — the details, which float highest
//
// Usage: swift RenderBrand.swift <output-root>

import AppKit
import CoreGraphics
import CoreText
import Foundation

// MARK: - Palette (derived from AppIcon.icon)

func srgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [r, g, b, a])!
}

enum Palette {
    // The brand orange-red, straight from icon.json: srgb(1.0, 0.14913, 0.0)
    static let brand      = srgb(1.000, 0.149, 0.000)
    static let brandLight = srgb(1.000, 0.290, 0.110)
    static let brandDeep  = srgb(0.831, 0.114, 0.000)
    static let antenna    = srgb(0.878, 0.180, 0.035)

    static let cream      = srgb(1.000, 0.945, 0.918)
    static let creamDeep  = srgb(0.988, 0.855, 0.816)

    static let fieldTop   = srgb(0.094, 0.067, 0.063)
    static let fieldBot   = srgb(0.027, 0.020, 0.024)
    static let glow       = srgb(1.000, 0.231, 0.078)

    static let subtitle   = srgb(0.62, 0.58, 0.57)
}

// MARK: - The mark, in a unit square (0…1, top-left origin)

enum Mark {
    // Body
    static let bodyX0: CGFloat = 0.227, bodyX1: CGFloat = 0.776
    static let bodyY0: CGFloat = 0.359, bodyY1: CGFloat = 0.705
    static let bodyRadius: CGFloat = 0.052

    // Antenna: a capsule sweeping up and to the right, from behind the body
    static let antA = CGPoint(x: 0.332, y: 0.371)
    static let antB = CGPoint(x: 0.669, y: 0.239)
    static let antWidth: CGFloat = 0.0215

    // Two bars
    static let barX0: CGFloat = 0.278, barX1: CGFloat = 0.498
    static let barH: CGFloat = 0.0305
    static let bar1Y: CGFloat = 0.474, bar2Y: CGFloat = 0.571

    // Dial
    static let dial = CGPoint(x: 0.649, y: 0.520)
    static let dialR: CGFloat = 0.086

    // Full visual bounds of the mark (antenna tip to body bottom)
    static let bboxX0 = bodyX0, bboxX1 = bodyX1
    static let bboxY0 = antB.y - antWidth, bboxY1 = bodyY1
    static var bboxW: CGFloat { bboxX1 - bboxX0 }
    static var bboxH: CGFloat { bboxY1 - bboxY0 }
}

/// Maps the unit square into the frame so the mark's bounding box has `targetH`
/// of the frame height and is centred on (`cx`, `cy`) expressed in frame points.
struct Placement {
    let scale: CGFloat
    let ox: CGFloat
    let oy: CGFloat

    init(frame: CGSize, bboxHeightFraction: CGFloat, centre: CGPoint) {
        let targetH = frame.height * bboxHeightFraction
        scale = targetH / Mark.bboxH
        ox = centre.x - (Mark.bboxX0 + Mark.bboxW / 2) * scale
        oy = centre.y - (Mark.bboxY0 + Mark.bboxH / 2) * scale
    }

    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: ox + x * scale, y: oy + y * scale)
    }
    func len(_ v: CGFloat) -> CGFloat { v * scale }
    var bodyRect: CGRect {
        let a = pt(Mark.bodyX0, Mark.bodyY0), b = pt(Mark.bodyX1, Mark.bodyY1)
        return CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
    }
}

// MARK: - Drawing helpers

func capsule(from a: CGPoint, to b: CGPoint, width: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: a)
    p.addLine(to: b)
    return p.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round,
                  miterLimit: 10)
}

func linearGradient(_ ctx: CGContext, rect: CGRect, top: CGColor, bottom: CGColor) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                       colors: [top, bottom] as CFArray, locations: [0, 1])!
    ctx.saveGState()
    ctx.clip(to: rect)
    ctx.drawLinearGradient(g,
                           start: CGPoint(x: rect.midX, y: rect.minY),
                           end: CGPoint(x: rect.midX, y: rect.maxY),
                           options: [])
    ctx.restoreGState()
}

// MARK: - Layers

/// Opaque, full-bleed. A near-black field with a warm ember behind the mark —
/// the app's own UI is black, and a dark plate makes the orange carry across a room.
func drawBack(_ ctx: CGContext, size: CGSize, glowCentre: CGPoint, glowRadius: CGFloat) {
    let full = CGRect(origin: .zero, size: size)
    linearGradient(ctx, rect: full, top: Palette.fieldTop, bottom: Palette.fieldBot)

    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let comps = Palette.glow.components!
    let g = CGGradient(colorsSpace: cs, colors: [
        srgb(comps[0], comps[1], comps[2], 0.34),
        srgb(comps[0], comps[1], comps[2], 0.14),
        srgb(comps[0], comps[1], comps[2], 0.00),
    ] as CFArray, locations: [0, 0.45, 1])!
    ctx.saveGState()
    ctx.clip(to: full)
    ctx.drawRadialGradient(g, startCenter: glowCentre, startRadius: 0,
                           endCenter: glowCentre, endRadius: glowRadius,
                           options: [])
    ctx.restoreGState()
}

/// Antenna then body. The antenna is a touch deeper so it reads as behind.
func drawMiddle(_ ctx: CGContext, p: Placement) {
    ctx.saveGState()
    ctx.setFillColor(Palette.antenna)
    ctx.addPath(capsule(from: p.pt(Mark.antA.x, Mark.antA.y),
                        to: p.pt(Mark.antB.x, Mark.antB.y),
                        width: p.len(Mark.antWidth)))
    ctx.fillPath()
    ctx.restoreGState()

    let body = p.bodyRect
    let r = p.len(Mark.bodyRadius)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: r, cornerHeight: r,
                       transform: nil))
    ctx.clip()
    linearGradient(ctx, rect: body, top: Palette.brandLight, bottom: Palette.brandDeep)
    ctx.restoreGState()
}

/// Bars and dial — the highest-floating layer in the parallax stack.
func drawFront(_ ctx: CGContext, p: Placement) {
    let h = p.len(Mark.barH)
    for y in [Mark.bar1Y, Mark.bar2Y] {
        let a = p.pt(Mark.barX0, y), b = p.pt(Mark.barX1, y)
        ctx.saveGState()
        ctx.addPath(capsule(from: CGPoint(x: a.x + h / 2, y: a.y),
                            to: CGPoint(x: b.x - h / 2, y: b.y), width: h))
        ctx.clip()
        linearGradient(ctx,
                       rect: CGRect(x: a.x, y: a.y - h / 2, width: b.x - a.x, height: h),
                       top: Palette.cream, bottom: Palette.creamDeep)
        ctx.restoreGState()
    }

    let c = p.pt(Mark.dial.x, Mark.dial.y)
    let r = p.len(Mark.dialR)
    let box = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
    ctx.saveGState()
    ctx.addEllipse(in: box)
    ctx.clip()
    linearGradient(ctx, rect: box, top: Palette.cream, bottom: Palette.creamDeep)
    ctx.restoreGState()
}

// MARK: - Text (Top Shelf only)

func drawText(_ ctx: CGContext, _ s: String, size: CGFloat, weight: NSFont.Weight,
              color: CGColor, at origin: CGPoint, tracking: CGFloat = 0) {
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: NSColor(cgColor: color)!,
        .kern: tracking,
    ]
    let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: s, attributes: attrs))
    ctx.saveGState()
    // Un-flip for text: the context is top-left oriented.
    ctx.translateBy(x: origin.x, y: origin.y)
    ctx.scaleBy(x: 1, y: -1)
    ctx.textPosition = .zero
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

func textWidth(_ s: String, size: CGFloat, weight: NSFont.Weight,
               tracking: CGFloat = 0) -> CGFloat {
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let line = CTLineCreateWithAttributedString(NSAttributedString(
        string: s, attributes: [.font: font, .kern: tracking]))
    return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
}

// MARK: - Canvas

func makeContext(_ size: CGSize) -> CGContext {
    let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)
    // Work in top-left coordinates throughout.
    ctx.translateBy(x: 0, y: size.height)
    ctx.scaleBy(x: 1, y: -1)
    return ctx
}

func write(_ ctx: CGContext, to path: String) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString,
                                              1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("  \(URL(fileURLWithPath: path).lastPathComponent)  "
          + "\(ctx.width)×\(ctx.height)")
}

// MARK: - Compositions

func renderIconLayer(_ layer: String, size: CGSize, to path: String) {
    let ctx = makeContext(size)
    // 62% of frame height. Centred on 0.455 rather than 0.5: the antenna is visually
    // light while the body is the mass, so geometric centring of the bounding box
    // leaves the body sitting low. Raising it puts the body near optical centre.
    let p = Placement(frame: size, bboxHeightFraction: 0.62,
                      centre: CGPoint(x: size.width / 2, y: size.height * 0.455))
    switch layer {
    case "Back":
        drawBack(ctx, size: size,
                 glowCentre: CGPoint(x: p.bodyRect.midX, y: p.bodyRect.midY),
                 glowRadius: size.width * 0.62)
    case "Middle": drawMiddle(ctx, p: p)
    case "Front":  drawFront(ctx, p: p)
    default: fatalError("unknown layer \(layer)")
    }
    write(ctx, to: path)
}

func renderTopShelf(size: CGSize, to path: String) {
    let ctx = makeContext(size)
    let s = size.height / 720  // scale relative to the 1x design

    // Measure the whole lockup (mark + gap + text) and centre it. The wide variant
    // is a different aspect ratio and can be cropped at the edges, so anchoring to
    // the centre keeps both variants balanced and safe.
    let markH: CGFloat = 0.58
    let titleSize = 168 * s
    let subSize = 52 * s
    let gap = 116 * s

    let markScale = (size.height * markH) / Mark.bboxH
    let markW = Mark.bboxW * markScale
    let textW = max(textWidth("Lytter", size: titleSize, weight: .bold, tracking: -2 * s),
                    textWidth("LIVE DANISH RADIO", size: subSize, weight: .medium,
                              tracking: 6 * s))
    let lockupX = (size.width - (markW + gap + textW)) / 2

    let p = Placement(frame: size, bboxHeightFraction: markH,
                      centre: CGPoint(x: lockupX + markW / 2, y: size.height * 0.455))

    drawBack(ctx, size: size,
             glowCentre: CGPoint(x: p.bodyRect.midX, y: p.bodyRect.midY),
             glowRadius: size.width * 0.46)
    drawMiddle(ctx, p: p)
    drawFront(ctx, p: p)

    // Text is optically centred on the body, not on the mark's bounding box.
    let textX = lockupX + markW + gap
    let baseline = p.bodyRect.midY + titleSize * 0.10
    drawText(ctx, "Lytter", size: titleSize, weight: .bold, color: Palette.cream,
             at: CGPoint(x: textX, y: baseline), tracking: -2 * s)
    drawText(ctx, "LIVE DANISH RADIO", size: subSize, weight: .medium,
             color: Palette.subtitle,
             at: CGPoint(x: textX + 5 * s, y: baseline + 76 * s), tracking: 6 * s)

    write(ctx, to: path)
}

// MARK: - Main

let root = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath
let brand = "\(root)/lytter/Assets.xcassets/Brand Assets.brandassets"

print("App Icon (400×240) — parallax stack")
for layer in ["Back", "Middle", "Front"] {
    let dir = "\(brand)/App Icon.imagestack/\(layer).imagestacklayer/Content.imageset"
    renderIconLayer(layer, size: CGSize(width: 400, height: 240),
                    to: "\(dir)/\(layer.lowercased())@1x.png")
    renderIconLayer(layer, size: CGSize(width: 800, height: 480),
                    to: "\(dir)/\(layer.lowercased())@2x.png")
}

print("App Icon — App Store (1280×768)")
for layer in ["Back", "Middle", "Front"] {
    let dir = "\(brand)/App Icon - App Store.imagestack/"
        + "\(layer).imagestacklayer/Content.imageset"
    renderIconLayer(layer, size: CGSize(width: 1280, height: 768),
                    to: "\(dir)/\(layer.lowercased()).png")
}

print("Top Shelf")
renderTopShelf(size: CGSize(width: 1920, height: 720),
               to: "\(brand)/Top Shelf Image.imageset/topshelf@1x.png")
renderTopShelf(size: CGSize(width: 3840, height: 1440),
               to: "\(brand)/Top Shelf Image.imageset/topshelf@2x.png")
renderTopShelf(size: CGSize(width: 2320, height: 720),
               to: "\(brand)/Top Shelf Image Wide.imageset/topshelf-wide@1x.png")
renderTopShelf(size: CGSize(width: 4640, height: 1440),
               to: "\(brand)/Top Shelf Image Wide.imageset/topshelf-wide@2x.png")

print("done")
