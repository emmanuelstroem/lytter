//
//  PlayerVolumeView.swift
//  ios
//
//  Created by Emmanuel on 27/07/2025.
//

import SwiftUI

struct PlayerVolumeView: View {
    @Binding var volume: Double
    let showVolumeControl: Bool
    let onVolumeChange: ((Double) -> Void)?
    @State private var isDragging = false
    init(
        volume: Binding<Double>,
        showVolumeControl: Bool = true,
        onVolumeChange: ((Double) -> Void)? = nil
    ) {
        self._volume = volume
        self.showVolumeControl = showVolumeControl
        self.onVolumeChange = onVolumeChange
    }
    
        var body: some View {
        if showVolumeControl {
            GeometryReader { geometry in
                CapsuleSlider(value: $volume, isDragging: $isDragging, onVolumeChange: onVolumeChange)
                    .frame(height: min(geometry.size.width, geometry.size.height) * 0.2)
                    .frame(maxWidth: geometry.size.width)
                    .padding(.horizontal, geometry.size.width * 0.05)
                    .scaleEffect(isDragging ? 1.03 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
                    .opacity(isDragging ? 0.8 : 0.6)
            }
        }
    }
}


struct CapsuleSlider: View {
    @Binding var value: Double // Range 0.0 - 1.0
    @Binding var isDragging: Bool
    let onVolumeChange: ((Double) -> Void)?
    
    init(value: Binding<Double>, isDragging: Binding<Bool>, onVolumeChange: ((Double) -> Void)? = nil) {
        self._value = value
        self._isDragging = isDragging
        self.onVolumeChange = onVolumeChange
    }
    
    var body: some View {
        VolumeSlideriOS(value: $value, isDragging: $isDragging, onVolumeChange: onVolumeChange)
    }
}

struct VolumeSlideriOS: View {
    @Binding var value: Double // Range 0.0 - 1.0
    @Binding var isDragging: Bool
    let onVolumeChange: ((Double) -> Void)?
    
    init(value: Binding<Double>, isDragging: Binding<Bool>, onVolumeChange: ((Double) -> Void)? = nil) {
        self._value = value
        self._isDragging = isDragging
        self.onVolumeChange = onVolumeChange
    }
    
    var body: some View {
        #if os(iOS)
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            HStack(alignment: .center) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: min(geometry.size.width, geometry.size.height), weight: .medium))
                    .foregroundColor(.white)
                    .animation(.easeInOut(duration: 0.2), value: isDragging)
                
                // Slider
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: geometry.size.width * 0.8, height: isDragging ? height : height * 0.6)
                    
                    // Progress track
                    Capsule()
                        .fill(Color.white.opacity(isDragging ? 0.8 : 0.6))
                        .frame(width: CGFloat(value) * (geometry.size.width * 0.8), height: isDragging ? height : height * 0.6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .animation(.easeInOut(duration: 0.2), value: isDragging)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            isDragging = true
                            let location = gesture.location.x
                            let sliderWidth = width - geometry.size.width * 0.08
                            let newValue = min(max(0, location / sliderWidth), 1)
                            value = newValue
                            onVolumeChange?(value)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
                
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: min(geometry.size.width, geometry.size.height), weight: .medium))
                    .foregroundColor(.white)
                    .animation(.easeInOut(duration: 0.2), value: isDragging)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        #endif
    }
}




#Preview {
    PlayerVolumeView(
        volume: .constant(0.7)
    ) { newVolume in
        print("Volume changed to: \(newVolume)")
    }
} 
