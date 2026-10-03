//
//  PlayingMark.swift
//  lytter
//

import SwiftUI

/// The mark beside a station that is playing: a dot and two rings around it, like a speaker
/// cone seen head on, that pulse in and out (F38).
///
/// It replaced `speaker.wave.2.fill`, which said "this one" but not "now". It is only ever
/// shown while sound is playing (`DRServiceManager.isAudible`), so it always moves when it
/// is on screen; with Reduce Motion on it is the same mark, still.
///
/// Sized by the surrounding font, like the symbol it replaced: a hidden `circle` symbol
/// takes the space, so the mark sits where an `Image` would in the same row and follows
/// Dynamic Type. Drawn in the foreground style, so callers colour it as they did the symbol.
struct PlayingMark: View {
    /// The symbol whose box the mark takes. Tests measure it to check names still fit
    /// beside the mark.
    static let sizingSymbol = "circle"

    /// One full in-and-out, in seconds. Slow enough to read as breathing, not as a level
    /// meter — it does not follow the audio, and a fast pulse would pretend to.
    static let period: Double = 1.6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: Self.sizingSymbol)
            .hidden()
            .overlay {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
                    let phase = reduceMotion
                        ? nil
                        : timeline.date.timeIntervalSinceReferenceDate / Self.period
                    Canvas { context, size in
                        Self.draw(in: &context, size: size, phase: phase)
                    }
                }
            }
            .accessibilityHidden(true)
    }

    /// Where each ring sits, as a fraction of the mark's radius, at rest.
    static let ringRadii: [Double] = [0.48, 0.8]

    /// A ring as drawn: its radius as a fraction of the mark's, and its opacity.
    struct Ring: Equatable {
        var radius: Double
        var opacity: Double
    }

    /// The rings at `phase` (in periods); `nil` is at rest, for Reduce Motion. They move out
    /// of step, the outer one a little behind, so the pulse travels outward the way a cone
    /// pushes air.
    static func rings(at phase: Double?) -> [Ring] {
        ringRadii.enumerated().map { index, rest in
            guard let phase else { return Ring(radius: rest, opacity: 1) }
            let wave = sin(2 * .pi * (phase - Double(index) * 0.18))
            return Ring(radius: rest * (1 + 0.1 * wave), opacity: 0.75 + 0.25 * wave)
        }
    }

    private static func draw(in context: inout GraphicsContext, size: CGSize, phase: Double?) {
        let radius = min(size.width, size.height) / 2
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let lineWidth = max(radius * 0.16, 1)

        func circle(_ r: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2))
        }

        context.fill(circle(radius * 0.22), with: .foreground)

        for ring in rings(at: phase) {
            // Inset by half the stroke so the outer ring stays inside the symbol's box at
            // its widest.
            var ringContext = context
            ringContext.opacity = ring.opacity
            ringContext.stroke(circle(min(radius * ring.radius, radius - lineWidth / 2)),
                               with: .foreground, lineWidth: lineWidth)
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        PlayingMark().font(.caption)
        PlayingMark().font(.title3)
        PlayingMark().font(.system(size: 40))
    }
    .foregroundStyle(Color.accentColor)
    .padding()
}
