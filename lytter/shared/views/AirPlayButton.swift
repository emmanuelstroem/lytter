//
//  AirPlayButton.swift
//  ios
//
//  Created by Emmanuel on 28/07/2025.
//

import SwiftUI
import AVKit
// MARK: - SwiftUI Native AirPlay Button

#if os(iOS) || os(tvOS)
// AVRoutePickerView, the system's own AirPlay control, is a UIKit view with no AppKit
// counterpart -- macOS routes audio output a different way entirely. This wrapper only
// exists to bridge it into SwiftUI, so it only exists where the thing it bridges does.
struct AirPlayButton: UIViewRepresentable {
    let size: CGFloat
    /// Semantic by default, so the glyph follows the system appearance. Callers that
    /// sit in a row of de-emphasised controls pass `.secondaryLabel` to match them.
    let tint: PlatformColor
    
    init(size: CGFloat, tint: PlatformColor = .label) {
        self.size = size
        self.tint = tint
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        
        // Configure the view
        view.prioritizesVideoDevices = false
        view.activeTintColor = UIColor.systemBlue
        view.tintColor = tint
        view.backgroundColor = UIColor.clear
        
        // Set delegate
        view.delegate = context.coordinator
        
        // Ensure proper sizing and interaction
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        
        // Set minimum size for touch interaction and center the content
        let buttonSize = max(size, 44)
        view.frame = CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize)

        view.contentMode = .center
        
        return view
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // Update tint colors if needed
        uiView.activeTintColor = UIColor.systemBlue
        uiView.tintColor = tint
        
        // Ensure proper frame and centering
        let buttonSize = max(size, 44)
        uiView.frame = CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize)
        uiView.contentMode = .center
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, AVRoutePickerViewDelegate {
        var parent: AirPlayButton
        
        init(_ parent: AirPlayButton) {
            self.parent = parent
        }
        
        func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) {
        }
        
        func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView) {
        }
    }
}
#endif

// MARK: - AirPlay Button with Frame

struct AirPlayButtonView: View {
    let size: CGFloat
    let tint: PlatformColor

    init(size: CGFloat, tint: PlatformColor = .label) {
        self.size = size
        self.tint = tint
    }

    var body: some View {
        #if os(iOS) || os(tvOS)
        AirPlayButton(size: size, tint: tint)
            .frame(width: size, height: size, alignment: .center)
            .clipped() // Ensure the content stays within bounds
            .contentShape(Rectangle()) // Ensure the entire frame is tappable
            .accessibilityLabel("AirPlay")
        #else
        // No AirPlay picker on macOS yet -- output routing there is a menu-bar affair,
        // not a view -- nor on visionOS, which has no AVRoutePickerView: there it is
        // Control Centre's. Reserves the space rather than disappearing, so a row of controls
        // around it does not visibly shift once a macOS equivalent exists to fill it.
        Color.clear
            .frame(width: size, height: size, alignment: .center)
        #endif
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        AirPlayButtonView(size: 24)
        AirPlayButtonView(size: 32)
    }
    .padding()
}
