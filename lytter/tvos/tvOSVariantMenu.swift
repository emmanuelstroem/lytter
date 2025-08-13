//
//  tvOSVariantMenu.swift
//  lytter
//
//  Created by Assistant on 12/08/2025.
//

import SwiftUI

#if os(tvOS)
/// A custom, focus-friendly overlay menu for tvOS that mimics SwiftUI's Menu interaction.
/// - Presents a full-screen dimmed background and a centered panel with focusable options.
/// - Dismisses on background tap or remote's back/menu via onExitCommand.
struct tvOSVariantMenu<Label: View, Item: Identifiable & Hashable>: View {
    let items: [Item]
    let label: () -> Label
    let itemTitle: (Item) -> String
    let onSelect: (Item) -> Void

    @State private var isPresented = false
    @FocusState private var focusedItemId: Item.ID?

    var body: some View {
        ZStack {
            // The trigger/control that shows the menu
            Button(action: { isPresented = true }) {
                label()
            }
            .buttonStyle(.card)
            .focusEffectDisabled(isPresented)

            if isPresented {
                // Dimmed backdrop
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { isPresented = false }
                    .zIndex(1)

                // Centered panel with focusable options
                overlayPanel
                    .zIndex(2)
                    .transition(.scale)
                    .onAppear {
                        if let first = items.first {
                            focusedItemId = first.id
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented)
        .onExitCommand {
            if isPresented { isPresented = false }
        }
    }

    private var overlayPanel: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Vælg variant")
                .font(.title2)
                .bold()
                .foregroundColor(.white)

            ScrollView(.vertical) {
                // Two columns to keep focus movement predictable on tvOS
                LazyVGrid(columns: [GridItem(.fixed(500)), GridItem(.fixed(500))], spacing: 24) {
                    ForEach(items) { item in
                        Button(action: {
                            onSelect(item)
                            isPresented = false
                        }) {
                            Text(itemTitle(item))
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 80)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.card)
                        .focused($focusedItemId, equals: item.id)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .frame(width: 1100, height: 700)
    }
}
#endif


