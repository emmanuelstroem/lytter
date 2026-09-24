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
/// Designed to be used as a Button label with tvOSMusicCardButtonStyle,
/// so the entire item (image and text) scales together on focus.
struct tvOSChannelCard: View {
    let channel: DRChannel

    /// What to call the channel, when the caller knows better than the card does.
    ///
    /// A card on a shelf may stand for a station ("P4") or for one particular district
    /// ("P4 - København"), and only the shelf knows which — the channel alone cannot say.
    var titleOverride: String? = nil
    @EnvironmentObject private var serviceManager: DRServiceManager
    @Environment(\.isFocused) private var isFocused

    private var currentProgram: DREpisode? {
        serviceManager.getCurrentProgram(for: channel)
    }

    private var artworkURL: URL? {
        guard let program = currentProgram,
              let urlString = program.primaryImageURL ?? program.landscapeImageURL
        else { return nil }
        return URL(string: urlString)
    }

    // Match by base channel name so any regional variant counts as "this" channel
    private var isCurrentChannel: Bool {
        serviceManager.playingChannel?.name == channel.name
    }

    /// The same anatomy as the iOS card: the station's name on a band of glass across the
    /// foot of the artwork, and what is on it now beneath the card, on the background.
    ///
    /// Two lines of text under the artwork was the old arrangement, and it made a station
    /// look like a different product on the television than it does on the phone. The band
    /// also puts the name where the eye already is — on the image.
    var body: some View {
        let displayTitle = titleOverride
            ?? ((channel.district != nil) ? channel.name : channel.title)

        VStack(alignment: .leading, spacing: 10) {
            CachedAsyncImage(url: artworkURL,
                             maxPixelSize: ImageCacheService.thumbnailMaxPixelSize) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    Color.white.opacity(0.12)
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 64))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .frame(width: 300, height: 300)
            .clipped()
            .overlay(alignment: .bottom) { nameBand(displayTitle) }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(isFocused ? 0.85 : 0), lineWidth: 0.5)
            )
            .overlay(alignment: .topTrailing) {
                if isCurrentChannel {
                    NowPlayingBadge(isPlaying: serviceManager.isPlaying)
                        .padding(10)
                }
            }
            .shadow(color: .white.opacity(isFocused ? 0.55 : 0), radius: 18, x: 0, y: 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isFocused)

            // Beneath the card, on the background, where it needs no scrim to be read.
            //
            // Inset by 6: the card button style rounds its own container, and text starting
            // flush at x=0 had its first letter clipped by that corner — "Orientering" read
            // as "rientering".
            Text(currentProgram?.programmeName ?? "")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.gray)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .frame(width: 300, alignment: .leading)
                .frame(minHeight: 22)
        }
    }

    private func nameBand(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { CaptionBackdrop(fades: false) }
            .captionOnArtwork()
    }
}

/// Small badge shown on the top-right corner of a channel card when that channel is playing.
struct NowPlayingBadge: View {
    let isPlaying: Bool

    var body: some View {
        Image(systemName: isPlaying ? "waveform" : "pause.fill")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .symbolEffect(.variableColor.iterative.dimInactiveLayers, isActive: isPlaying)
    }
}

/// Custom button style that scales and lifts the entire item (image + text) on focus.
/// The system focus effect (which creates _UIReplicantView) is disabled because
/// this style renders its own scale + shadow effects.
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
