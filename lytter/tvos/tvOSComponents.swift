//
//  tvOSComponents.swift
//  lytter
//
//  Created by Assistant on 08/08/2025.
//

import SwiftUI
#if os(tvOS)
import TVUIKit
#endif
import UIKit

#if os(tvOS)
struct TVPosterViewRepresentable: UIViewRepresentable {
    let title: String
    let subtitle: String?
    let imageURL: URL?
    let onSelect: () -> Void
    
    func makeUIView(context: Context) -> TVPosterView {
        let poster = TVPosterView()
        poster.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didSelect)))
        poster.isUserInteractionEnabled = true
        return poster
    }
    
    func updateUIView(_ uiView: TVPosterView, context: Context) {
        uiView.title = title
        uiView.subtitle = subtitle
        if let url = imageURL {
            // updateUIView runs on every layout pass. Going through the cache means a
            // repeat pass is a dictionary lookup rather than another download.
            ImageCacheService.shared.loadImage(
                from: url.absoluteString,
                maxPixelSize: ImageCacheService.thumbnailMaxPixelSize) { image in
                guard let image else { return }
                uiView.image = image
                uiView.contentMode = .scaleAspectFit
            }
        } else {
            uiView.image = nil
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }
    
    class Coordinator: NSObject {
        let onSelect: () -> Void
        init(onSelect: @escaping () -> Void) { self.onSelect = onSelect }
        @objc func didSelect() { onSelect() }
    }
}

struct FocusableLockupView: UIViewRepresentable {
    let title: String
    let subtitle: String?
    let imageURL: URL?

    func makeUIView(context: Context) -> FocusableLockupUIView {
        let view = FocusableLockupUIView()
        return view
    }

    func updateUIView(_ uiView: FocusableLockupUIView, context: Context) {
        uiView.setContent(title: title, subtitle: subtitle, imageURL: imageURL)
    }
}

class FocusableLockupUIView: UIView {
    private let containerView = UIView()
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    private var parallaxGroup: UIMotionEffectGroup?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // Container with rounded corners
        containerView.layer.cornerRadius = 20
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // Image
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.alpha = 0.6 // default opacity
        containerView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.75)
        ])
        
        // Labels
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        subtitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        subtitleLabel.textColor = .lightGray
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -8)
        ])
        
        // Make non-interactive; wrapping SwiftUI containers (e.g., Button/Menu) handle input
        isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func setContent(title: String, subtitle: String?, imageURL: URL?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        if let url = imageURL {
            ImageCacheService.shared.loadImage(
                from: url.absoluteString,
                maxPixelSize: ImageCacheService.thumbnailMaxPixelSize) { [weak self] image in
                guard let self, let image else { return }
                self.imageView.image = image
            }
        } else {
            imageView.image = nil
        }
    }
    
    // Non-focusable; focus is managed by SwiftUI wrappers
    override var canBecomeFocused: Bool { false }
    
    private func addParallax() {
        guard parallaxGroup == nil else { return }
        let horizontal = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
        horizontal.minimumRelativeValue = -10
        horizontal.maximumRelativeValue = 10
        
        let vertical = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
        vertical.minimumRelativeValue = -10
        vertical.maximumRelativeValue = 10
        
        let group = UIMotionEffectGroup()
        group.motionEffects = [horizontal, vertical]
        addMotionEffect(group)
        parallaxGroup = group
    }
    
    private func removeParallax() {
        if let group = parallaxGroup {
            removeMotionEffect(group)
            parallaxGroup = nil
        }
    }
    
    // Gestures and presses intentionally not handled here
}
#endif

#if os(tvOS)
/// Full shelf item: square artwork + title + subtitle.
struct tvOSMusicCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        tvOSMusicCardBody(configuration: configuration)
    }

    private struct tvOSMusicCardBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            configuration.label
                .scaleEffect(isFocused ? 1.1 : 1.0, anchor: .center)
                .shadow(color: .black.opacity(isFocused ? 0.55 : 0), radius: 24, x: 0, y: 18)
                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isFocused)
                // Prevent tvOS from creating a _UIReplicantView for the default
                // focus lift effect — we own all focus visuals above.
                .focusEffectDisabled()
        }
    }
}
#endif
