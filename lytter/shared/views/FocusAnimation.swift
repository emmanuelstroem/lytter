//
//  FocusAnimation.swift
//  lytter
//

import SwiftUI

extension View {
    /// The animation for a control taking or losing focus.
    ///
    /// A spring that overshoots and settles, which reads well — but it is exactly the kind of
    /// bounce Reduce Motion asks an app to drop. With it on, the same change runs as a short
    /// ease with no overshoot: focus still visibly arrives, it just does not bounce.
    func focusAnimation<V: Equatable>(value: V) -> some View {
        modifier(FocusAnimation(value: value))
    }
}

private struct FocusAnimation<V: Equatable>: ViewModifier {
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(
            reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.28, dampingFraction: 0.72),
            value: value)
    }
}
