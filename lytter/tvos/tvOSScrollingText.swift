//
//  tvOSScrollingText.swift
//  lytter
//

import SwiftUI
import UIKit

#if os(tvOS)
/// Long text the remote can scroll.
///
/// A SwiftUI `ScrollView` on tvOS scrolls only to bring focus into view, so text inside one
/// with nothing focusable cannot be scrolled at all. That is what a long programme
/// description in the player's info sheet ran into: the words ran off the bottom and no
/// swipe or click reached them.
///
/// A `UITextView` can be scrolled. Made selectable it becomes focusable, and its pan
/// gesture is told to accept the remote's touch surface. Clicking up or down on the
/// clickpad pages it too, because not every remote has a touch surface.
///
/// Sizes itself to its text up to the height it is offered, so a short description takes
/// only the room it needs and a long one fills what there is and scrolls.
struct tvOSScrollingText: UIViewRepresentable {
    let text: String
    var fontSize: CGFloat = 22
    var lineSpacing: CGFloat = 5
    var opacity: CGFloat = 0.7

    func makeUIView(context: Context) -> RemoteScrollingTextView {
        let view = RemoteScrollingTextView()
        view.isSelectable = true
        view.isScrollEnabled = true
        view.isUserInteractionEnabled = true
        view.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.showsVerticalScrollIndicator = true
        view.indicatorStyle = .white
        return view
    }

    func updateUIView(_ view: RemoteScrollingTextView, context: Context) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        view.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: UIColor.white.withAlphaComponent(opacity),
            .paragraphStyle: paragraph
        ])
    }

    func sizeThatFits(_ proposal: ProposedViewSize,
                      uiView: RemoteScrollingTextView,
                      context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite else { return nil }
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let height = proposal.height.map { min(fitting.height, $0) } ?? fitting.height
        return CGSize(width: width, height: height)
    }
}

/// The text view, with clickpad paging.
final class RemoteScrollingTextView: UITextView {

    /// How far one click moves, as a share of what is visible: enough to make progress,
    /// with a line or two of overlap so the reader keeps their place.
    static let pageFraction: CGFloat = 0.8

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first,
              press.type == .upArrow || press.type == .downArrow,
              let target = Self.offset(after: press.type,
                                       from: contentOffset.y,
                                       visibleHeight: bounds.height,
                                       contentHeight: contentSize.height)
        else {
            super.pressesBegan(presses, with: event)
            return
        }
        setContentOffset(CGPoint(x: contentOffset.x, y: target), animated: true)
    }

    /// Where a click leaves the text, or nil when it has nowhere to go — the text already
    /// fits, or is already at that end — so the press is passed on instead of swallowed.
    static func offset(after press: UIPress.PressType,
                       from current: CGFloat,
                       visibleHeight: CGFloat,
                       contentHeight: CGFloat) -> CGFloat? {
        let bottom = max(contentHeight - visibleHeight, 0)
        guard bottom > 0 else { return nil }

        let step = visibleHeight * pageFraction
        let target: CGFloat
        switch press {
        case .downArrow: target = min(current + step, bottom)
        case .upArrow: target = max(current - step, 0)
        default: return nil
        }
        return abs(target - current) < 0.5 ? nil : target
    }
}
#endif
