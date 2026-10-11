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
// AVRoutePickerView, the system's own AirPlay control, bridged into SwiftUI. The Mac's is
// an AppKit view, and works differently enough to be bridged on its own, below.
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

#if os(macOS)
/// The Mac's AVRoutePickerView. Where the phone's routes the app's audio session, this one
/// routes a single player's audio, so it is handed the player — a new one with every station.
/// With none, nothing is playing, and there is nothing to send anywhere.
struct MacAirPlayButton: NSViewRepresentable {
    let player: AVPlayer?
    let tint: PlatformColor

    func makeNSView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        // A glyph like the controls beside it, not a push button.
        view.isRoutePickerButtonBordered = false
        update(view)
        return view
    }

    func updateNSView(_ view: AVRoutePickerView, context: Context) {
        update(view)
    }

    private func update(_ view: AVRoutePickerView) {
        if view.player !== player { view.player = player }
        view.setRoutePickerButtonColor(tint, for: .normal)
        view.setRoutePickerButtonColor(tint, for: .normalHighlighted)
        view.setRoutePickerButtonColor(.controlAccentColor, for: .active)
        view.setRoutePickerButtonColor(.controlAccentColor, for: .activeHighlighted)
    }
}
#endif

// MARK: - AirPlay Button with Frame

struct AirPlayButtonView: View {
    let size: CGFloat
    let tint: PlatformColor
    #if os(macOS)
    /// The player whose audio is sent. Only the Mac's picker needs it.
    let player: AVPlayer?
    #endif

    #if os(macOS)
    init(size: CGFloat, tint: PlatformColor = .label, player: AVPlayer? = nil) {
        self.size = size
        self.tint = tint
        self.player = player
    }
    #else
    init(size: CGFloat, tint: PlatformColor = .label) {
        self.size = size
        self.tint = tint
    }
    #endif

    /// Whether there is a picker to draw. Where there is not, the view only holds its place,
    /// and a row with no room to keep for it leaves it out.
    static var isAvailable: Bool {
        #if os(iOS) || os(tvOS) || os(macOS)
        true
        #else
        false
        #endif
    }

    var body: some View {
        #if os(iOS) || os(tvOS)
        AirPlayButton(size: size, tint: tint)
            .frame(width: size, height: size, alignment: .center)
            .clipped() // Ensure the content stays within bounds
            .contentShape(Rectangle()) // Ensure the entire frame is tappable
            .accessibilityLabel("AirPlay")
        #elseif os(macOS)
        MacAirPlayButton(player: player, tint: tint)
            .frame(width: size, height: size, alignment: .center)
            .disabled(player == nil)
            .accessibilityLabel("AirPlay")
        #else
        // No AirPlay picker on visionOS, which has no AVRoutePickerView: there it is
        // Control Centre's. Reserves the space rather than disappearing, so a row of controls
        // around it does not shift.
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
