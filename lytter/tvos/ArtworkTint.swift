//
//  ArtworkTint.swift
//  lytter
//

import SwiftUI
import CoreImage

#if os(tvOS)
/// The colour of a programme's artwork, for the surfaces drawn around it: Now Playing's
/// backdrop, and the focused row of its schedule.
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

    /// Held dark, for a backdrop with white text on it.
    var backdrop: Color {
        Color(UIColor(hue: hue, saturation: min(saturation * 1.2, 1),
                      brightness: min(brightness, 0.45), alpha: 1))
    }

    /// The artwork's colour brought forward: an average of a photograph is a muddy version
    /// of its strongest colour, so the saturation is raised, and the brightness set to where
    /// white text still reads on it. A grey artwork stays grey.
    var accent: Color {
        Color(UIColor(hue: hue, saturation: saturation < 0.08 ? saturation : min(saturation * 1.6, 0.85),
                      brightness: 0.55, alpha: 1))
    }
}
#endif
