//
//  PlatformTypes.swift
//  lytter
//

import SwiftUI

#if os(macOS)
import AppKit

/// The image and color types shared code builds against, aliased to each platform's own.
///
/// One pair of names rather than `#if os(macOS)` scattered through every file that touches
/// an image or a color. The alias alone is not always enough — UIKit and AppKit chose
/// different names for the same thing often enough (`UIColor.label` vs
/// `NSColor.labelColor`, `UIImage(cgImage:)` vs `NSImage(cgImage:size:)`) that a few gaps
/// need closing by hand. Closed here, as code elsewhere needed them, rather than guessed at
/// up front for names nothing uses yet.
typealias PlatformImage = NSImage
typealias PlatformColor = NSColor

extension NSColor {
    static var label: NSColor { .labelColor }
    static var secondaryLabel: NSColor { .secondaryLabelColor }
}

extension NSImage {
    /// UIKit builds an image straight from a `CGImage`; AppKit wants the size too. The
    /// image already knows its own pixel size, so callers keep the simpler UIKit-shaped call.
    convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// UIKit exposes this as a property; AppKit only as a rendering method. `forProposedRect:
    /// nil` asks for the image's own backing size rather than a resample.
    var cgImage: CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
#else
import UIKit

typealias PlatformImage = UIImage
typealias PlatformColor = UIColor
#endif

extension Image {
    /// `Image(uiImage:)` and `Image(nsImage:)` are the same call with different names.
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}
