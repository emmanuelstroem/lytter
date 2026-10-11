//
//  ArtworkTint.swift
//  lytter
//

import SwiftUI
import CoreImage

#if os(iOS) || os(tvOS) || os(visionOS)
/// The colour of a programme's artwork, for the surfaces drawn around it: Apple TV's Now
/// Playing backdrop, and the highlighted row of the schedule on every platform with one.
///
/// Measured from the image the cache already holds for the artwork, so asking for it does not
/// fetch the artwork a second time.
struct ArtworkTint {
    let hue: CGFloat
    let saturation: CGFloat
    let brightness: CGFloat

    /// The programme on air on `channel`'s artwork, as Now Playing shows it.
    static func artworkURL(for channel: DRChannel, serviceManager: DRServiceManager) -> URL? {
        guard let program = serviceManager.getCurrentProgram(for: channel),
              let urlString = program.primaryImageURL ?? program.landscapeImageURL
        else { return nil }
        return URL(string: urlString)
    }

    /// The artwork's average colour, or nil when there is no artwork or it cannot be read.
    static func of(_ url: URL?) async -> ArtworkTint? {
        guard let url,
              let uiImage = await ImageCacheService.shared.image(for: url.absoluteString),
              let cgImage = uiImage.cgImage else { return nil }

        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(x: extent.origin.x, y: extent.origin.y,
                                        z: extent.size.width, w: extent.size.height)
        ]), let output = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext().render(output, toBitmap: &bitmap, rowBytes: 4,
                           bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                           format: .RGBA8, colorSpace: nil)

        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255,
                blue: CGFloat(bitmap[2]) / 255, alpha: 1)
            .getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return ArtworkTint(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// A colour read as an artwork's is: for a station with no artwork, its own colour, so
    /// that its highlight is drawn the same way as one taken from a picture. The station's
    /// colour as it stands is chosen for the tile's name, which on P1, P3 and P4 is near-black;
    /// white on P3's light green did not read.
    init(_ color: Color) {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        self.init(hue: hue, saturation: saturation, brightness: brightness)
    }

    init(hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
    }

    /// Held dark, for a backdrop with white text on it.
    var backdrop: Color {
        Color(UIColor(hue: hue, saturation: min(saturation * 1.2, 1),
                      brightness: min(brightness, 0.45), alpha: 1))
    }

    /// The artwork's colour brought forward: an average of a photograph is a muddy version
    /// of its strongest colour, so the saturation is raised, and the brightness set for a
    /// mark on the dark page — the schedule's on-air time and its play marks. A grey artwork
    /// stays grey. Too light for white body text on it: that is `fill`.
    var accent: Color { brought(toBrightness: 0.55) }

    /// The accent, deep enough to fill a row of body text in white: 4.5:1 at the least,
    /// whatever the hue (`ArtworkTintTests`). At the accent's own brightness a yellow or a
    /// green came out near 4:1, under the least for text that size. The schedule's
    /// highlighted row is filled with it on every platform (`ScheduleTint`).
    var fill: Color { brought(toBrightness: Self.fillBrightness) }

    static let fillBrightness: CGFloat = 0.45

    private var broughtSaturation: CGFloat {
        saturation < 0.08 ? saturation : min(saturation * 1.6, 0.85)
    }

    func brought(toBrightness brightness: CGFloat) -> Color {
        Color(uiColor: broughtColor(brightness: brightness))
    }

    func broughtColor(brightness: CGFloat) -> UIColor {
        UIColor(hue: hue, saturation: broughtSaturation, brightness: brightness, alpha: 1)
    }
}
#endif
