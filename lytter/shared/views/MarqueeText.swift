import SwiftUI
import Foundation
import Combine

public struct MarqueeText: View {
    public var text: String
    public var font: Font
    public var leftFade: CGFloat
    public var rightFade: CGFloat
    public var startDelay: Double
    public var alignment: Alignment
    
    @State private var animate = false
    /// The text's real rendered size, measured from a hidden copy. It used to be guessed —
    /// 8pt a character and 16pt tall whatever the font — which clipped any text larger than
    /// 16pt to a strip, and so ruled out Dynamic Type for everything set in a marquee.
    @State private var textSize: CGSize = .zero
    /// With Reduce Motion on the text never scrolls; what does not fit is truncated.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var isCompact = false
    /// Set on the accessibility element itself; see `accessibilityID(_:)`.
    var accessibilityID = ""
    
    public var body: some View {
        let stringWidth  = textSize.width
        let stringHeight = textSize.height
        
        // Create our animations
        let animation = Animation
            .linear(duration: Double(stringWidth) / 30)
            .delay(startDelay)
            .repeatForever(autoreverses: false)
        
        let nullAnimation = Animation.linear(duration: 0)
        
        GeometryReader { geo in
            // Decide if scrolling is needed
            let needsScrolling = !reduceMotion && (stringWidth > geo.size.width)
            
            ZStack {
                if needsScrolling {
                    // MARK: - Scrolling (Marquee) version
                    makeMarqueeTexts(
                        stringWidth: stringWidth,
                        stringHeight: stringHeight,
                        geoWidth: geo.size.width,
                        animation: animation,
                        nullAnimation: nullAnimation
                    )
                    // force left alignment when scrolling
                    .frame(
                        minWidth: 0,
                        maxWidth: .infinity,
                        minHeight: 0,
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )
                    // Masked within its own frame. The mask used to be widened by
                    // `leftFade` past the leading edge, so the text scrolled out over the
                    // margin beside it — nearly to the screen's edge in the full player.
                    // At rest the text starts at the leading edge, in line with the line
                    // above it, so the leading fade comes in only as the scroll begins.
                    .mask(
                        fadeMask(
                            leftFade: animate ? leftFade : 0,
                            rightFade: rightFade
                        )
                        .animation(animate ? .easeIn(duration: 0.3).delay(startDelay) : nil,
                                   value: animate)
                    )
                } else {
                    // MARK: - Non-scrolling version
                    Text(text)
                        .font(font)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .onValueChanged(of: text) { _, _ in
                            self.animate = false // No scrolling needed
                        }
                        .frame(
                            minWidth: 0,
                            maxWidth: .infinity,
                            minHeight: 0,
                            maxHeight: .infinity,
                            alignment: alignment // use alignment only if not scrolling
                        )
                }
            }
            .onAppear {
                // Trigger scrolling if needed
                self.animate = needsScrolling
            }
            // The measurement lands a moment after the text changes, and a new text size
            // (Dynamic Type) changes it too, so restart from whether it now overflows.
            .onValueChanged(of: needsScrolling) { _, scroll in restart(scrolling: scroll) }
            .onValueChanged(of: text) { _, _ in restart(scrolling: needsScrolling) }
        }
        .frame(height: stringHeight)
        .frame(maxWidth: isCompact ? stringWidth : nil)
        .background(alignment: .topLeading) {
            // The measuring copy: same text and font, never drawn, at its ideal size.
            Text(text)
                .font(font)
                .lineLimit(1)
                .fixedSize()
                .hidden()
                .onGeometryChange(for: CGSize.self, of: \.size) { textSize = $0 }
        }
        .onDisappear {
            self.animate = false
        }
        // One element, in the marquee's own frame. Scrolling, it draws the text twice, and
        // VoiceOver read both — and outlined the pair, one far off to the side. The element
        // is a clear overlay, not the drawn text: before iOS 26 an element's frame takes in
        // everything drawn under it, the first copy too, far off the leading edge at the end
        // of its scroll, however it is masked or clipped.
        .accessibilityHidden(true)
        .overlay {
            Color.clear
                .accessibilityElement()
                .accessibilityLabel(Text(verbatim: text))
                .accessibilityAddTraits(.isStaticText)
                .accessibilityIdentifier(accessibilityID)
        }
    }
    
    /// Stops any running scroll and, if the text overflows, starts it again from the top on
    /// the next run loop — an animation cannot be restarted in the same update.
    private func restart(scrolling: Bool) {
        animate = false
        guard scrolling else { return }
        DispatchQueue.main.async { animate = true }
    }

    // MARK: - Marquee pair of texts
    @ViewBuilder
    private func makeMarqueeTexts(
        stringWidth: CGFloat,
        stringHeight: CGFloat,
        geoWidth: CGFloat,
        animation: Animation,
        nullAnimation: Animation
    ) -> some View {
        // Two stacked texts moving across in opposite phases
        Group {
            Text(text)
                .lineLimit(1)
                .font(font)
                .offset(x: animate ? -stringWidth - stringHeight * 2 : 0)
                .animation(animate ? animation : nullAnimation, value: animate)
                .fixedSize(horizontal: true, vertical: false)
            
            Text(text)
                .lineLimit(1)
                .font(font)
                .offset(x: animate ? 0 : stringWidth + stringHeight * 2)
                .animation(animate ? animation : nullAnimation, value: animate)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
    
    // MARK: - Fade mask
    @ViewBuilder
    private func fadeMask(leftFade: CGFloat, rightFade: CGFloat) -> some View {
        HStack(spacing: 0) {
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0), Color.black]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: leftFade)
            
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.black]),
                startPoint: .leading,
                endPoint: .trailing
            )
            
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.black.opacity(0)]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: rightFade)
        }
    }
    
    // MARK: - Initializer
    public init(
        text: String,
        font: Font,
        leftFade: CGFloat,
        rightFade: CGFloat,
        startDelay: Double,
        alignment: Alignment? = nil
    ) {
        self.text      = text
        self.font      = font
        self.leftFade  = leftFade
        self.rightFade = rightFade
        self.startDelay = startDelay
        self.alignment = alignment ?? .topLeading
    }
}

extension MarqueeText {
    public func makeCompact(_ compact: Bool = true) -> Self {
        var view = self
        view.isCompact = compact
        return view
    }

    /// An identifier for UI tests, set on the marquee's one element. `.accessibilityIdentifier`
    /// from outside lands on whatever wraps the marquee, not on the element itself.
    public func accessibilityID(_ identifier: String) -> Self {
        var view = self
        view.accessibilityID = identifier
        return view
    }
}

extension View {
    /// Backwards-compatible wrapper for value change handling
    @ViewBuilder func onValueChanged<T: Equatable>(of value: T, perform onChange: @escaping (T, T) -> Void) -> some View {
        if #available(tvOS 17, iOS 17, macOS 14, *) {
            self.onChange(of: value) { oldValue, newValue in
                onChange(oldValue, newValue)
            }
        } else {
            self.onReceive(Just(value)) { newValue in
                onChange(value, newValue)
            }
        }
    }
}
