//
//  KnockoutTextView.swift
//  lytter
//
//  Created by Emmanuel on 09/08/2025.
//

import SwiftUI

// MARK: - KnockoutTextView Components
struct KnockoutTextView: View {
    var text: String
    var backgroundColor: Color = .blue
    
    var body: some View {
        ZStack {
            // Square with transparent text
            TextMaskView(text: text, backgroundColor: backgroundColor)
        }
    }
}

struct TextMaskView: View {
    var text: String
    var backgroundColor: Color
    
    var body: some View {
        // Solid color square
        backgroundColor
            .overlay {
                // Transparent text mask - using fixed size instead of GeometryReader
                Text(text)
                    .font(.system(size: 24, weight: .black, design: .default))
                    .minimumScaleFactor(0.1)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(.black)
                    .blendMode(.destinationOut) // Punch out the text
            }
            .compositingGroup() // Required for destinationOut to work properly
    }
}
