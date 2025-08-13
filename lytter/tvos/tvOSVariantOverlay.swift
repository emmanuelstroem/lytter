//
//  tvOSVariantOverlay.swift
//  lytter
//
//  Created by Assistant on 12/08/2025.
//

import SwiftUI

#if os(tvOS)
struct tvOSVariantOverlay: View {
    let title: String
    let variants: [DRChannel]
    let onSelect: (DRChannel) -> Void
    let onDismiss: () -> Void

    @FocusState private var focusedVariantId: String?

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Popover-style panel
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 12) {
                    ForEach(variants, id: \.id) { variant in
                        Button(action: {
                            onSelect(variant)
                            onDismiss()
                        }) {
                            HStack {
                                Text(variant.district ?? variant.title)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 70)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(focusedVariantId == variant.id ? 0.18 : 0.08))
                            )
                            .contentShape(Capsule(style: .continuous))
                            .focusEffectDisabled()
                        }
                        .buttonStyle(.plain)
                        .focused($focusedVariantId, equals: variant.id)
                        .hoverEffectDisabled()
                        .focusEffectDisabled()
                    }
                }
                .padding(.horizontal, 8)
                .focusEffectDisabled()
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .frame(width: 680)
            .transition(.scale)
            .onAppear {
                if let first = variants.first { focusedVariantId = first.id }
            }
        }
        .focusSection()
        .onExitCommand { onDismiss() }
        .animation(.easeInOut(duration: 0.2), value: variants.count)
    }
}
#endif


