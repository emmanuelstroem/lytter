// RenderBrandAssets.swift — generates every app icon, the tvOS Top Shelf artwork and the
// fallback now-playing artwork.
//
// The mark is a transistor radio: white body, diagonal antenna, two red bars and a
// dial, on a red field. It is defined in a unit square and drawn with CoreGraphics, so it stays
// vector-exact at every size rather than being upscaled from a master PNG.
//
// The radio is flat: solid white, its bars and dial solid red, with no shading, sheen,
// rim light or shadow. Shaded, the white's highlights washed over the red and the bars
// read pink rather than red. Only the field keeps its light — a gradient and a soft glow
// — as AppIcon.icon's automatic gradient does.
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

/// Three palettes: the brand one, a deeper one for dark appearance, and a luminance-only
/// one for the iOS tinted variant, where the system applies the user's tint to a
/// greyscale image.
///
/// The mark is a white radio on a red field, its bars and dial picking the red back up
/// so they read as cut into the body. It replaced a red radio on a cream field, which in
/// turn replaced one on maroon; the red field reads as red at every size, which the
/// earlier dark field never did, and needs no light/dark compromise to do it.
struct Palette {
    var body, control: CGColor
    var fieldTop, fieldBottom, glow: CGColor

    /// The red is DR's own, from DR's colour system: "DR rød" #FF001E (Pantone 185), the
    /// `.icon`'s fill, and the bars and dial are that red, flat. The field's gradient is
    /// not new colours but mixes of it with two of DR's documented steps — #FD3A3A, the
    /// light "accessibility light red", at the top, and #55001B, a dark step, at the
    /// bottom — so the field stays that one red, lit, rather than drifting towards orange
    /// as #FF2600 did.
    static let brand = Palette(
        body:          srgb(1.000, 1.000, 1.000),
        control:       srgb(1.000, 0.000, 0.118),   // #FF001E: DR rød itself
        fieldTop:      srgb(0.997, 0.091, 0.162),   // #FE1729: DR rød, 40% to #FD3A3A
        fieldBottom:   srgb(0.880, 0.000, 0.116),   // #E0001D: DR rød, 18% to #55001B
        glow:          srgb(0.994, 0.421, 0.421))   // #FE6B6B: #FD3A3A, 25% to white

    /// The same mark on a deeper red, for dark appearance — the matching `.icon` fill is
    /// #CC001D, DR rød 30% of the way to #55001B. Still DR's red, but not a bright square
    /// on a dark Home Screen.
    static let dark = Palette(
        body:          brand.body,
        control:       srgb(0.800, 0.000, 0.114),   // #CC001D: 30% to #55001B, as the field
        fieldTop:      srgb(0.800, 0.000, 0.114),   // #CC001D: 30%
        fieldBottom:   srgb(0.587, 0.000, 0.110),   // #96001C: 62%
        glow:          srgb(0.996, 0.102, 0.167))   // #FE1A2B: DR rød, 45% to #FD3A3A

    /// Greyscale: a dark field and a light radio, so the user's tint lands on the radio
    /// the way it lands on the white glass of the `.icon`.
    static let tinted = Palette(
        body:          srgb(0.980, 0.980, 0.980),
        control:       srgb(0.420, 0.420, 0.420),
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

// MARK: - Elements

func drawAntenna(_ ctx: CGContext, _ p: Placement, _ pal: Palette) {
    let a = p.pt(Mark.antA.x, Mark.antA.y), b = p.pt(Mark.antB.x, Mark.antB.y)
    ctx.addPath(capsule(a, b, p.len(Mark.antWidth)))
    ctx.setFillColor(pal.body); ctx.fillPath()
}

func drawBody(_ ctx: CGContext, _ p: Placement, _ pal: Palette) {
    ctx.addPath(p.bodyPath)
    ctx.setFillColor(pal.body); ctx.fillPath()
}

func drawControls(_ ctx: CGContext, _ p: Placement, _ pal: Palette) {
    ctx.setFillColor(pal.control)
    let h = p.len(Mark.barH)
    for y in [Mark.bar1Y, Mark.bar2Y] {
        let a = p.pt(Mark.barX0, y), b = p.pt(Mark.barX1, y)
        ctx.addPath(capsule(CGPoint(x: a.x + h / 2, y: a.y),
                            CGPoint(x: b.x - h / 2, y: b.y), h))
        ctx.fillPath()
    }
    let c = p.pt(Mark.dial.x, Mark.dial.y), r = p.len(Mark.dialR)
    ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
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
    drawAntenna(ctx, p, pal)
    drawBody(ctx, p, pal)
    drawControls(ctx, p, pal)
    writePNG(ctx, to: path, opaque: true)
}

/// One layer of a layered icon — the tvOS parallax stack or the visionOS solid image
/// stack. No baked inter-element shadows: the layers move independently and the system
/// draws the shadows between them.
func renderStackLayer(_ layer: String, size: CGSize, placement p: Placement, to path: String) {
    let ctx = makeContext(size)
    let pal = Palette.brand
    switch layer {
    case "Back":
        drawField(ctx, size: size, pal: pal,
                  glowAt: CGPoint(x: p.bodyRect.midX, y: p.bodyRect.midY),
                  glowRadius: size.width * 0.62, glowAlpha: 0.34)
    case "Middle":
        drawAntenna(ctx, p, pal)
        drawBody(ctx, p, pal)
    case "Front":
        drawControls(ctx, p, pal)
    default: fatalError("unknown layer \(layer)")
    }
    writePNG(ctx, to: path, opaque: layer == "Back")
}

/// tvOS: a wide plate, the mark a little above centre where the system's focus lift
/// leaves it looking centred.
func renderTVLayer(_ layer: String, size: CGSize, to path: String) {
    renderStackLayer(layer, size: size,
                     placement: Placement(frame: size, bboxHeightFraction: 0.62,
                                          centre: CGPoint(x: size.width / 2,
                                                          y: size.height * 0.455)),
                     to: path)
}

/// visionOS: a square the system masks to a circle, so the mark is centred on its own
/// bounding box and kept well inside the circle (its farthest point, the antenna tip, is
/// about a third of the side from the centre).
func renderVisionLayer(_ layer: String, side: CGFloat, to path: String) {
    let size = CGSize(width: side, height: side)
    renderStackLayer(layer, size: size,
                     placement: Placement(frame: size, bboxHeightFraction: 0.46,
                                          centre: CGPoint(x: side / 2, y: side / 2)),
                     to: path)
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

/// The mark and the app's name. No tagline: the image is baked, so any words beyond the
/// name could not be localised, and "Lytter" reads the same in every language.
func renderTopShelf(size: CGSize, to path: String) {
    let ctx = makeContext(size)
    let pal = Palette.brand
    let s = size.height / 720

    let markH: CGFloat = 0.58
    let titleSize = 168 * s, gap = 116 * s, tracking = -2 * s
    let markW = Mark.bboxW * ((size.height * markH) / Mark.bboxH)
    let textW = textWidth("Lytter", size: titleSize, weight: .bold, tracking: tracking)
    let lockupX = (size.width - (markW + gap + textW)) / 2
    let p = Placement(frame: size, bboxHeightFraction: markH,
                      centre: CGPoint(x: lockupX + markW / 2, y: size.height * 0.48))

    drawField(ctx, size: size, pal: pal,
              glowAt: CGPoint(x: p.bodyRect.midX, y: p.bodyRect.midY),
              glowRadius: size.width * 0.46, glowAlpha: 0.34)
    drawAntenna(ctx, p, pal)
    drawBody(ctx, p, pal)
    drawControls(ctx, p, pal)

    // Capitals centred on the body, which is where the eye puts the mark's centre —
    // not on its bounding box, which the antenna stretches upward.
    let capHeight = NSFont.systemFont(ofSize: titleSize, weight: .bold).capHeight
    drawText(ctx, "Lytter", size: titleSize, weight: .bold, color: pal.body,
             at: CGPoint(x: lockupX + markW + gap, y: p.bodyRect.midY + capHeight / 2),
             tracking: tracking)
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
renderSquareIcon(side: 1024, pal: .dark, glowAlpha: 0.30, to: "\(appIcon)/dark.png")
renderSquareIcon(side: 1024, pal: .tinted, glowAlpha: 0.18, to: "\(appIcon)/tinted.png")

print("watchOS app icon")
renderSquareIcon(side: 1024, pal: .brand, glowAlpha: 0.34,
                 to: "\(watchIcon)/watch.png")

// Full-bleed and opaque, the same as iOS. The transparent-margin "icon on a plate"
// convention this replaced predates Big Sur; the system has drawn its own rounded-square
// shape and shadow around a submitted icon rather than applying one for several OS
// releases now, so a plate with a transparent margin around it stayed exactly as
// transparent as authored — which, against a Dock that is itself dark or translucent,
// read as more black square than red radio.
print("macOS app icon — opaque, full bleed")
for (px, name) in [(16, "all_16x16"), (32, "all_32x32"), (32, "all_32x32 1"),
                   (64, "all_64x64"), (128, "all_128x128"), (256, "all_256x256 1"),
                   (256, "all_256x256"), (512, "all_512x512 1"), (512, "all_512x512"),
                   (1024, "store")] {
    renderSquareIcon(side: CGFloat(px), pal: .brand, glowAlpha: 0.34,
                     to: "\(appIcon)/\(name).png")
}

// The fallback now-playing artwork, for a station that sends none: the icon's own square,
// so the Lock Screen, Control Center and the Mac's Now Playing show the same mark as the
// Home Screen. 300 points at every scale, as AudioPlayerService has always used.
print("Now-playing fallback artwork")
for (px, suffix) in [(300, "@1x"), (600, "@2x"), (900, "@3x")] {
    renderSquareIcon(side: CGFloat(px), pal: .brand, glowAlpha: 0.34,
                     to: "\(assets)/DefaultArtwork.imageset/artwork\(suffix).png")
}

print("visionOS app icon — solid image stack")
for layer in ["Back", "Middle", "Front"] {
    let dir = "\(assets)/AppIcon visionOS.solidimagestack/"
        + "\(layer).solidimagestacklayer/Content.imageset"
    renderVisionLayer(layer, side: 1024, to: "\(dir)/\(layer.lowercased()).png")
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
