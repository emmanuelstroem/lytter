//
//  AirPlayButton.swift
//  ios
//
//  Created by Emmanuel on 28/07/2025.
//

import SwiftUI
import AVKit
// MARK: - SwiftUI Native AirPlay Button

struct AirPlayButton: UIViewRepresentable {
    let size: CGFloat
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        
        // Configure the view
        view.prioritizesVideoDevices = false
        view.activeTintColor = UIColor.systemBlue
        view.tintColor = UIColor.label
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
        uiView.tintColor = UIColor.label
        
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

// MARK: - AirPlay Button with Frame

struct AirPlayButtonView: View {
    let size: CGFloat
    
    var body: some View {
        AirPlayButton(size: size)
            .frame(width: size, height: size, alignment: .center)
            .clipped() // Ensure the content stays within bounds
            .contentShape(Rectangle()) // Ensure the entire frame is tappable
            .accessibilityLabel("AirPlay")
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
