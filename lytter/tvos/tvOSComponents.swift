//
//  tvOSComponents.swift
//  lytter
//
//  Created by Assistant on 08/08/2025.
//

import SwiftUI
import TVUIKit
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
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data, let image = UIImage(data: data) else { return }
                DispatchQueue.main.async {
                    uiView.image = image
                    uiView.contentMode = .scaleAspectFit
//                    uiview.image.clipsToBounds = true
                }
            }.resume()
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
    let onSelect: () -> Void
    
    func makeUIView(context: Context) -> FocusableLockupUIView {
        let view = FocusableLockupUIView()
        view.onSelect = onSelect
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
    var onSelect: (() -> Void)?
    
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
        
        // Tap gesture
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
#if os(tvOS)
        // Ensure the Siri Remote select press triggers the gesture on tvOS
        tap.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
#endif
        isUserInteractionEnabled = true
        addGestureRecognizer(tap)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func setContent(title: String, subtitle: String?, imageURL: URL?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        if let url = imageURL {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self = self, let data = data, let image = UIImage(data: data) else { return }
                DispatchQueue.main.async { self.imageView.image = image }
            }.resume()
        } else {
            imageView.image = nil
        }
    }
    
    override var canBecomeFocused: Bool { true }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        let isFocusing = (context.nextFocusedView == self)
        
        if isFocusing {
            // Animate ONLY the image on gaining focus
            UIViewPropertyAnimator(duration: 0.4, curve: .easeInOut) {
                self.imageView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                self.imageView.alpha = 1.0
            }.startAnimation()
            addParallax()
        } else if context.previouslyFocusedView == self {
            // Instantly reset image on losing focus
            imageView.transform = .identity
            imageView.alpha = 0.6
            removeParallax()
        }
    }
    
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
    
    @objc private func didTap() { onSelect?() }
    
    // Extra safety: handle primary select via pressesEnded as well
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .select }) {
            onSelect?()
        } else {
            super.pressesEnded(presses, with: event)
        }
    }
}
#endif

struct tvOSChannelCard: View {
    let channel: DRChannel
    let onSelect: () -> Void
    @EnvironmentObject private var serviceManager: DRServiceManager
    
    var body: some View {
        // For districtized channels (e.g., "P4 Bornholm"), show only the base name ("P4")
        let displayTitle = (channel.district != nil) ? channel.name : channel.title
        FocusableLockupView(
            title: displayTitle,
            subtitle: serviceManager.getCurrentProgram(for: channel)?.cleanTitle(),
            imageURL: {
                if let program = serviceManager.getCurrentProgram(for: channel),
                   let urlString = program.landscapeImageURL ?? program.primaryImageURL {
                    return URL(string: urlString)
                }
                return nil
            }(),
            onSelect: onSelect
        )
        .frame(height: 300)
        .padding(.vertical, 10)
    }
}

struct tvOSSearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
            TextField("Search radios", text: $text)
                .focused($isFocused)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
            if !text.isEmpty {
                Button(action: { text = "" }) { Image(systemName: "xmark.circle.fill") }
            }
            Button(action: { isFocused = true }) { // focus to enable dictation via remote mic
                Image(systemName: "mic.fill")
            }
            .buttonStyle(.borderless) // avoid extra highlight styling
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .foregroundColor(.white)
    }
}

#if os(tvOS)
struct tvOSDistrictSelectionSheet: View {
    let primaryName: String
    let variants: [DRChannel]
    let onSelect: (DRChannel) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Select \(primaryName) district")
                .font(.title2)
                .bold()
                .foregroundColor(.white)
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(variants, id: \.id) { channel in
                        Button(action: {
                            onSelect(channel)
                            dismiss()
                        }) {
                            Text(channel.district ?? channel.title)
                            .font(.title3)
                            .background(.ultraThinMaterial)
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
//        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
//        .padding()
    }
}
#endif
