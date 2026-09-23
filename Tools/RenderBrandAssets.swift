// RenderBrandAssets.swift — generates every app icon and the tvOS Top Shelf artwork.
//
// The mark is a transistor radio: orange-red body, diagonal antenna, two cream bars
// and a dial. It is defined in a unit square and drawn with CoreGraphics, so it stays
// vector-exact at every size rather than being upscaled from a master PNG.
//
// Depth comes from a single light source above and slightly in front, the way Apple's
// own icons are lit. Every element responds to it:
//
//   body      vertical gradient, specular sheen, a rim light along the top edge,
//             darkening along the bottom, and a contact shadow on the background
//   antenna   cylindrical shading across its short axis, bright on the upper edge
//   bars      raised, each with its own shadow on the body and a top rim
//   dial      shaded as a sphere — highlight up and left, terminator lower right
//
// Shadows between elements are baked for the flat icons. They are NOT baked for the
// tvOS parallax stack, where the layers move independently and the system draws the
// inter-layer shadows itself; those layers get material shading only.
//
// Usage: swift Tools/RenderBrandAssets.swift <repo-root>

import AppKit
import CoreGraphics
import CoreText
import Foundation

// MARK: - Colour

func srgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [r, g, b, a])!
}
func white(_ a: Double) -> CGColor { srgb(1, 1, 1, a) }
func black(_ a: Double) -> CGColor { srgb(0, 0, 0, a) }

/// Two palettes: the brand one, and a luminance-only one for the iOS tinted variant,
/// where the system applies the user's tint to a greyscale image.
struct Palette {
    var bodyTop, bodyBottom, antenna: CGColor
    var controlTop, controlBottom: CGColor
    var fieldTop, fieldBottom, glow: CGColor

    static let brand = Palette(
        bodyTop:       srgb(1.000, 0.310, 0.125),
        bodyBottom:    srgb(0.796, 0.098, 0.000),
        antenna:       srgb(0.894, 0.200, 0.043),
        controlTop:    srgb(1.000, 0.957, 0.933),
        controlBottom: srgb(0.972, 0.816, 0.769),
        fieldTop:      srgb(0.102, 0.075, 0.071),
        fieldBottom:   srgb(0.020, 0.016, 0.018),
        glow:          srgb(1.000, 0.231, 0.078))

    /// Greyscale, matched to the brand palette's luminance so the tinted icon keeps
    /// the same internal contrast.
    static let tinted = Palette(
        bodyTop:       srgb(0.620, 0.620, 0.620),
        bodyBottom:    srgb(0.360, 0.360, 0.360),
        antenna:       srgb(0.470, 0.470, 0.470),
        controlTop:    srgb(0.980, 0.980, 0.980),
        controlBottom: srgb(0.855, 0.855, 0.855),
        fieldTop:      srgb(0.090, 0.090, 0.090),
        fieldBottom:   srgb(0.018, 0.018, 0.018),
        glow:          srgb(0.550, 0.550, 0.550))
}

// MARK: - The mark, in a unit square (0…1, top-left origin)

enum Mark {
    static let bodyX0: CGFloat = 0.227, bodyX1: CGFloat = 0.776
    static let bodyY0: CGFloat = 0.359, bodyY1: CGFloat = 0.705
    static let bodyRadius: CGFloat = 0.052

    static let antA = CGPoint(x: 0.332, y: 0.371)
    static let antB = CGPoint(x: 0.669, y: 0.239)
    static let antWidth: CGFloat = 0.0215

    static let barX0: CGFloat = 0.278, barX1: CGFloat = 0.498
    static let barH: CGFloat = 0.0305
    static let bar1Y: CGFloat = 0.474, bar2Y: CGFloat = 0.571

    static let dial = CGPoint(x: 0.649, y: 0.520)
    static let dialR: CGFloat = 0.086

    static let bboxX0 = bodyX0, bboxX1 = bodyX1
    static let bboxY0 = antB.y - antWidth, bboxY1 = bodyY1
    static var bboxW: CGFloat { bboxX1 - bboxX0 }
    static var bboxH: CGFloat { bboxY1 - bboxY0 }
}

struct Placement {
    let scale: CGFloat, ox: CGFloat, oy: CGFloat

    /// Maps the unit square onto a square region of `side`, origin (`x`, `y`).
    init(side: CGFloat, x: CGFloat = 0, y: CGFloat = 0) {
        scale = side; ox = x; oy = y
    }
    /// Sizes the mark so its bounding box is `bboxHeightFraction` of the frame height,
    /// centred on `centre`.
    init(frame: CGSize, bboxHeightFraction: CGFloat, centre: CGPoint) {
        scale = (frame.height * bboxHeightFraction) / Mark.bboxH
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
    var bodyPath: CGPath {
        let r = len(Mark.bodyRadius)
        return CGPath(roundedRect: bodyRect, cornerWidth: r, cornerHeight: r,
                      transform: nil)
    }
}

// MARK: - Primitives

func capsule(_ a: CGPoint, _ b: CGPoint, _ w: CGFloat) -> CGPath {
    let p = CGMutablePath(); p.move(to: a); p.addLine(to: b)
    return p.copy(strokingWithWidth: w, lineCap: .round, lineJoin: .round, miterLimit: 10)
}

func grad(_ ctx: CGContext, _ colors: [CGColor], _ locs: [CGFloat],
          from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                       colors: colors as CFArray, locations: locs)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation,
                                                             .drawsAfterEndLocation])
}

func radial(_ ctx: CGContext, _ colors: [CGColor], _ locs: [CGFloat],
            centre: CGPoint, radius: CGFloat) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                       colors: colors as CFArray, locations: locs)!
    ctx.drawRadialGradient(g, startCenter: centre, startRadius: 0,
                           endCenter: centre, endRadius: radius, options: [])
}

/// Runs `body` with the context clipped to `path`.
func clipped(_ ctx: CGContext, to path: CGPath, _ body: () -> Void) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip(); body(); ctx.restoreGState()
}

/// A light catching the top edge of a shape: a stroke along the path, faded out
/// below so it only reads on the lit side.
func rimLight(_ ctx: CGContext, path: CGPath, bounds: CGRect, width: CGFloat,
              alpha: Double) {
    clipped(ctx, to: path) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setStrokeColor(white(alpha))
        ctx.setLineWidth(width * 2)  // half is clipped away by the path
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        grad(ctx, [white(alpha), white(0)], [0, 1],
             from: CGPoint(x: bounds.midX, y: bounds.minY),
             to: CGPoint(x: bounds.midX, y: bounds.minY + bounds.height * 0.55))
        ctx.restoreGState()
    }
}

// MARK: - Elements

func drawAntenna(_ ctx: CGContext, _ p: Placement, _ pal: Palette, shadows: Bool) {
    let a = p.pt(Mark.antA.x, Mark.antA.y), b = p.pt(Mark.antB.x, Mark.antB.y)
    let w = p.len(Mark.antWidth)
    let path = capsule(a, b, w)

    if shadows {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: p.len(0.006)),
                      blur: p.len(0.010), color: black(0.45))
        ctx.addPath(path); ctx.setFillColor(pal.antenna); ctx.fillPath()
        ctx.restoreGState()
    }

    // Cylindrical shading across the short axis: bright on the upper-left edge.
    let dx = b.x - a.x, dy = b.y - a.y
    let len = max(hypot(dx, dy), 0.0001)
    let perp = CGPoint(x: -dy / len, y: dx / len)
    let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    clipped(ctx, to: path) {
        ctx.setFillColor(pal.antenna)
        ctx.fill(path.boundingBox.insetBy(dx: -w, dy: -w))
        grad(ctx, [white(0.42), white(0.0), black(0.30)], [0, 0.45, 1],
             from: CGPoint(x: mid.x - perp.x * w / 2, y: mid.y - perp.y * w / 2),
             to: CGPoint(x: mid.x + perp.x * w / 2, y: mid.y + perp.y * w / 2))
    }
}

func drawBody(_ ctx: CGContext, _ p: Placement, _ pal: Palette, shadows: Bool) {
    let rect = p.bodyRect, path = p.bodyPath

    if shadows {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: p.len(0.022)),
                      blur: p.len(0.042), color: black(0.55))
        ctx.addPath(path); ctx.setFillColor(pal.bodyBottom); ctx.fillPath()
        ctx.restoreGState()
    }

    clipped(ctx, to: path) {
        grad(ctx, [pal.bodyTop, pal.bodyBottom], [0, 1],
             from: CGPoint(x: rect.midX, y: rect.minY),
             to: CGPoint(x: rect.midX, y: rect.maxY))

        // Specular sheen, up and to the left of centre.
        radial(ctx, [white(0.20), white(0.06), white(0)], [0, 0.5, 1],
               centre: CGPoint(x: rect.midX - rect.width * 0.16,
                               y: rect.minY + rect.height * 0.10),
               radius: rect.width * 0.72)

        // The face turns away from the light along the bottom.
        grad(ctx, [black(0), black(0.26)], [0, 1],
             from: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.32),
             to: CGPoint(x: rect.midX, y: rect.maxY))
    }
    rimLight(ctx, path: path, bounds: rect, width: p.len(0.0035), alpha: 0.55)
}

func drawControls(_ ctx: CGContext, _ p: Placement, _ pal: Palette, shadows: Bool) {
    // Bars — raised strips, each casting onto the body.
    let h = p.len(Mark.barH)
    for y in [Mark.bar1Y, Mark.bar2Y] {
        let a = p.pt(Mark.barX0, y), b = p.pt(Mark.barX1, y)
        let path = capsule(CGPoint(x: a.x + h / 2, y: a.y),
                           CGPoint(x: b.x - h / 2, y: b.y), h)
        let box = path.boundingBox

        if shadows {
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: p.len(0.005)),
                          blur: p.len(0.009), color: black(0.38))
            ctx.addPath(path); ctx.setFillColor(pal.controlBottom); ctx.fillPath()
            ctx.restoreGState()
        }
        clipped(ctx, to: path) {
            grad(ctx, [pal.controlTop, pal.controlBottom], [0, 1],
                 from: CGPoint(x: box.midX, y: box.minY),
                 to: CGPoint(x: box.midX, y: box.maxY))
        }
        rimLight(ctx, path: path, bounds: box, width: p.len(0.0022), alpha: 0.75)
    }

    // Dial — shaded as a sphere rather than a flat disc.
    let c = p.pt(Mark.dial.x, Mark.dial.y), r = p.len(Mark.dialR)
    let box = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
    let disc = CGPath(ellipseIn: box, transform: nil)

    if shadows {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: p.len(0.008)),
                      blur: p.len(0.016), color: black(0.42))
        ctx.addPath(disc); ctx.setFillColor(pal.controlBottom); ctx.fillPath()
        ctx.restoreGState()
    }
    clipped(ctx, to: disc) {
        ctx.setFillColor(pal.controlBottom); ctx.fill(box)
        // Key light from up and to the left; terminator falls to the lower right.
        radial(ctx, [pal.controlTop, pal.controlTop, pal.controlBottom], [0, 0.35, 1],
               centre: CGPoint(x: c.x - r * 0.34, y: c.y - r * 0.38), radius: r * 1.68)
        // Bounce light along the lower-right edge keeps it from going dead.
        radial(ctx, [white(0.30), white(0)], [0, 1],
               centre: CGPoint(x: c.x + r * 0.52, y: c.y + r * 0.56), radius: r * 0.78)
    }
    rimLight(ctx, path: disc, bounds: box, width: p.len(0.0028), alpha: 0.80)
}

// MARK: - Fields

func drawField(_ ctx: CGContext, size: CGSize, pal: Palette, glowAt: CGPoint,
               glowRadius: CGFloat, glowAlpha: Double) {
    let full = CGRect(origin: .zero, size: size)
    ctx.saveGState(); ctx.clip(to: full)
    grad(ctx, [pal.fieldTop, pal.fieldBottom], [0, 1],
         from: CGPoint(x: size.width / 2, y: 0),
         to: CGPoint(x: size.width / 2, y: size.height))
    let g = pal.glow.components!
    radial(ctx, [srgb(g[0], g[1], g[2], glowAlpha),
                 srgb(g[0], g[1], g[2], glowAlpha * 0.4),
                 srgb(g[0], g[1], g[2], 0)], [0, 0.45, 1],
           centre: glowAt, radius: glowRadius)
    ctx.restoreGState()
}

// MARK: - Canvas

func makeContext(_ size: CGSize) -> CGContext {
    let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)
    ctx.translateBy(x: 0, y: size.height); ctx.scaleBy(x: 1, y: -1)
    return ctx
}

/// iOS and watchOS icons must be fully opaque — an alpha channel is an App Store
/// rejection, and the system applies its own mask.
func writePNG(_ ctx: CGContext, to path: String, opaque: Bool) {
    var image = ctx.makeImage()!
    if opaque {
        let flat = CGContext(data: nil, width: ctx.width, height: ctx.height,
                             bitsPerComponent: 8, bytesPerRow: 0,
                             space: CGColorSpace(name: CGColorSpace.sRGB)!,
                             bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        flat.setFillColor(black(1))
        flat.fill(CGRect(x: 0, y: 0, width: ctx.width, height: ctx.height))
        flat.draw(image, in: CGRect(x: 0, y: 0, width: ctx.width, height: ctx.height))
        image = flat.makeImage()!
    }
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString,
                                               1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("  \(url.lastPathComponent)  \(ctx.width)×\(ctx.height)"
          + (opaque ? "  opaque" : ""))
}

// MARK: - Compositions

/// Square icon, full-bleed on black. Used for iOS and watchOS.
func renderSquareIcon(side: CGFloat, pal: Palette, glowAlpha: Double, to path: String) {
    let size = CGSize(width: side, height: side)
    let ctx = makeContext(size)
    let p = Placement(side: side)
    drawField(ctx, size: size, pal: pal,
              glowAt: CGPoint(x: p.bodyRect.midX, y: p.bodyRect.midY),
              glowRadius: side * 0.62, glowAlpha: glowAlpha)
    drawAntenna(ctx, p, pal, shadows: true)
    drawBody(ctx, p, pal, shadows: true)
    drawControls(ctx, p, pal, shadows: true)
    writePNG(ctx, to: path, opaque: true)
}

/// macOS icon: the artwork sits on a rounded plate inset in the canvas, with
/// transparency outside it — the platform convention, unlike iOS.
func renderMacIcon(side: CGFloat, to path: String) {
    let size = CGSize(width: side, height: side)
    let ctx = makeContext(size)
    let pal = Palette.brand
    let inset = side * 0.0977                       // Apple's 824/1024 icon grid
    let plate = CGRect(x: inset, y: inset, width: side - 2 * inset,
                       height: side - 2 * inset)
    let platePath = CGPath(roundedRect: plate, cornerWidth: plate.width * 0.2237,
                           cornerHeight: plate.width * 0.2237, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: side * 0.012),
                  blur: side * 0.022, color: black(0.35))
    ctx.addPath(platePath); ctx.setFillColor(pal.fieldBottom); ctx.fillPath()
    ctx.restoreGState()

    clipped(ctx, to: platePath) {
        grad(ctx, [pal.fieldTop, pal.fieldBottom], [0, 1],
             from: CGPoint(x: plate.midX, y: plate.minY),
             to: CGPoint(x: plate.midX, y: plate.maxY))
        let p = Placement(side: plate.width, x: plate.minX, y: plate.minY)
        let g = pal.glow.components!
        radial(ctx, [srgb(g[0], g[1], g[2], 0.30), srgb(g[0], g[1], g[2], 0)], [0, 1],
               centre: CGPoint(x: p.bodyRect.midX, y: p.bodyRect.midY),
               radius: plate.width * 0.62)
        drawAntenna(ctx, p, pal, shadows: true)
        drawBody(ctx, p, pal, shadows: true)
        drawControls(ctx, p, pal, shadows: true)
    }
    rimLight(ctx, path: platePath, bounds: plate, width: side * 0.0022, alpha: 0.28)
    writePNG(ctx, to: path, opaque: false)
}

/// One layer of the tvOS parallax stack. No baked inter-element shadows: the layers
/// move independently and tvOS draws the shadows between them.
func renderTVLayer(_ layer: String, size: CGSize, to path: String) {
    let ctx = makeContext(size)
    let pal = Palette.brand
    let p = Placement(frame: size, bboxHeightFraction: 0.62,
                      centre: CGPoint(x: size.width / 2, y: size.height * 0.455))
    switch layer {
    case "Back":
        drawField(ctx, size: size, pal: pal,
                  glowAt: CGPoint(x: p.bodyRect.midX, y: p.bodyRect.midY),
                  glowRadius: size.width * 0.62, glowAlpha: 0.34)
    case "Middle":
        drawAntenna(ctx, p, pal, shadows: false)
        drawBody(ctx, p, pal, shadows: false)
    case "Front":
        drawControls(ctx, p, pal, shadows: false)
    default: fatalError("unknown layer \(layer)")
    }
    writePNG(ctx, to: path, opaque: layer == "Back")
}

// MARK: - Text (Top Shelf only)

func drawText(_ ctx: CGContext, _ s: String, size: CGFloat, weight: NSFont.Weight,
              color: CGColor, at origin: CGPoint, tracking: CGFloat = 0) {
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor(cgColor: color)!, .kern: tracking]))
    ctx.saveGState()
    ctx.translateBy(x: origin.x, y: origin.y); ctx.scaleBy(x: 1, y: -1)
    ctx.textPosition = .zero
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

func textWidth(_ s: String, size: CGFloat, weight: NSFont.Weight,
               tracking: CGFloat = 0) -> CGFloat {
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .kern: tracking]))
    return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
}

func renderTopShelf(size: CGSize, to path: String) {
    let ctx = makeContext(size)
    let pal = Palette.brand
    let s = size.height / 720

    let markH: CGFloat = 0.58
    let titleSize = 168 * s, subSize = 52 * s, gap = 116 * s
    let markW = Mark.bboxW * ((size.height * markH) / Mark.bboxH)
    let textW = max(textWidth("Lytter", size: titleSize, weight: .bold, tracking: -2 * s),
                    textWidth("LIVE DANISH RADIO", size: subSize, weight: .medium,
                              tracking: 6 * s))
    let lockupX = (size.width - (markW + gap + textW)) / 2
    let p = Placement(frame: size, bboxHeightFraction: markH,
                      centre: CGPoint(x: lockupX + markW / 2, y: size.height * 0.455))

    drawField(ctx, size: size, pal: pal,
              glowAt: CGPoint(x: p.bodyRect.midX, y: p.bodyRect.midY),
              glowRadius: size.width * 0.46, glowAlpha: 0.34)
    drawAntenna(ctx, p, pal, shadows: true)
    drawBody(ctx, p, pal, shadows: true)
    drawControls(ctx, p, pal, shadows: true)

    let textX = lockupX + markW + gap
    let baseline = p.bodyRect.midY + titleSize * 0.10
    drawText(ctx, "Lytter", size: titleSize, weight: .bold, color: pal.controlTop,
             at: CGPoint(x: textX, y: baseline), tracking: -2 * s)
    drawText(ctx, "LIVE DANISH RADIO", size: subSize, weight: .medium,
             color: srgb(0.62, 0.58, 0.57), at: CGPoint(x: textX + 5 * s,
                                                        y: baseline + 76 * s),
             tracking: 6 * s)
    writePNG(ctx, to: path, opaque: true)
}

// MARK: - Main

let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1]
                                           : FileManager.default.currentDirectoryPath
let assets = "\(root)/lytter/Assets.xcassets"
let brand = "\(assets)/Brand Assets.brandassets"
let appIcon = "\(assets)/AppIcon.appiconset"
let watchIcon = "\(assets)/AppIcon Watch.appiconset"

print("iOS app icon — opaque, full bleed")
renderSquareIcon(side: 1024, pal: .brand, glowAlpha: 0.34, to: "\(appIcon)/all.png")
renderSquareIcon(side: 1024, pal: .brand, glowAlpha: 0.22, to: "\(appIcon)/dark.png")
renderSquareIcon(side: 1024, pal: .tinted, glowAlpha: 0.18, to: "\(appIcon)/tinted.png")

print("watchOS app icon")
renderSquareIcon(side: 1024, pal: .brand, glowAlpha: 0.34,
                 to: "\(watchIcon)/watch.png")

print("macOS app icon — inset plate, transparent margin")
for (px, name) in [(16, "all_16x16"), (32, "all_32x32"), (32, "all_32x32 1"),
                   (64, "all_64x64"), (128, "all_128x128"), (256, "all_256x256 1"),
                   (256, "all_256x256"), (512, "all_512x512 1"), (512, "all_512x512"),
                   (1024, "store")] {
    renderMacIcon(side: CGFloat(px), to: "\(appIcon)/\(name).png")
}

print("tvOS app icon — parallax stack")
for layer in ["Back", "Middle", "Front"] {
    let dir = "\(brand)/App Icon.imagestack/\(layer).imagestacklayer/Content.imageset"
    renderTVLayer(layer, size: CGSize(width: 400, height: 240),
                  to: "\(dir)/\(layer.lowercased())@1x.png")
    renderTVLayer(layer, size: CGSize(width: 800, height: 480),
                  to: "\(dir)/\(layer.lowercased())@2x.png")
}
for layer in ["Back", "Middle", "Front"] {
    let dir = "\(brand)/App Icon - App Store.imagestack/"
        + "\(layer).imagestacklayer/Content.imageset"
    renderTVLayer(layer, size: CGSize(width: 1280, height: 768),
                  to: "\(dir)/\(layer.lowercased()).png")
}

print("tvOS Top Shelf")
renderTopShelf(size: CGSize(width: 1920, height: 720),
               to: "\(brand)/Top Shelf Image.imageset/topshelf@1x.png")
renderTopShelf(size: CGSize(width: 3840, height: 1440),
               to: "\(brand)/Top Shelf Image.imageset/topshelf@2x.png")
renderTopShelf(size: CGSize(width: 2320, height: 720),
               to: "\(brand)/Top Shelf Image Wide.imageset/topshelf-wide@1x.png")
renderTopShelf(size: CGSize(width: 4640, height: 1440),
               to: "\(brand)/Top Shelf Image Wide.imageset/topshelf-wide@2x.png")

print("done")
