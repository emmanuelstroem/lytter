//
//  tvOSRadioView.swift
//  lytter
//
//  Created by Assistant on 08/08/2025.
//

import SwiftUI

#if os(tvOS)
struct tvOSRadioView: View {
    @ObservedObject var serviceManager: DRServiceManager
    @ObservedObject var selectionState: SelectionState
    // Sheet removed; districts are presented via Menu wrapping the channel card
    
    @State private var menuIsFocused = false
    @FocusState private var focusedMenuChannelId: String?
    @State private var lastFocusedChannelId: String?
    @State private var selectedChannelForVariants: DRChannel?
    
    // One representative per base channel (deduped by name)
    private var primaryChannels: [DRChannel] {
        let grouped = Dictionary(grouping: serviceManager.availableChannels, by: { $0.name })
        let representatives: [DRChannel] = grouped.values.compactMap { group in
            // Prefer the variant without a district if it exists; otherwise pick the first by title
            if let noDistrict = group.first(where: { $0.district == nil }) {
                return noDistrict
            }
            return group.sorted { $0.title < $1.title }.first
        }
        return representatives.sorted { $0.title < $1.title }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                LinearGradient(colors: [.black, .black.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                VStack {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("DR Radio")
                        
                        if serviceManager.isLoading {
                            ProgressView().scaleEffect(1.4).tint(.white)
                        } else if let error = serviceManager.error {
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle").font(.system(size: 60)).foregroundColor(.orange)
                                Text(error).foregroundColor(.white)
                                Button("Retry") { serviceManager.loadChannels() }
                            }
                        } else if primaryChannels.isEmpty {
                            Text("No channels").foregroundColor(.white)
                        } else {
                            // Single horizontal list of primary channels
                            ScrollView(.horizontal) {
                                LazyHStack(spacing: 60) {
                                    ForEach(primaryChannels, id: \.id) { channel in
                                        let variants = serviceManager.availableChannels.filter { $0.name == channel.name }
                                        if variants.count <= 1 {
                                            Button {
                                                serviceManager.playChannel(channel)
                                                selectionState.selectChannel(channel)
                                            } label: {
                                                tvOSChannelCard(channel: channel)
                                                    .frame(width: 460, height: 300)
                                            }
                                            .buttonStyle(.card)
                                            .focused($focusedMenuChannelId, equals: channel.id)
                                            
                                        } else {
                                            Button {
                                                lastFocusedChannelId = channel.id
                                                selectedChannelForVariants = channel
                                            } label: {
                                                tvOSChannelCard(channel: channel)
                                                    .frame(width: 460, height: 300)
                                            }
                                            .buttonStyle(.card)
                                            .focused($focusedMenuChannelId, equals: channel.id)
                                        }
                                    }
                                }
                                .padding(.horizontal, 30)
                                .padding(.vertical, 10)
                                .focusSection()
                            }
                        }
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 60)
                    // While variants overlay is visible, block interaction and hide focus effects behind it
                    .allowsHitTesting(selectedChannelForVariants == nil)
                    .focusEffectDisabled(selectedChannelForVariants != nil)
                    .edgesIgnoringSafeArea(.horizontal)
                    
                }

                if let selectedChannel = selectedChannelForVariants {
                    // Build variants for selected channel
                    let selectedVariants = serviceManager.availableChannels.filter { $0.name == selectedChannel.name }
                    tvOSVariantOverlay(
                        title: selectedChannel.title,
                        variants: selectedVariants,
                        onSelect: { variant in
                            serviceManager.playChannel(variant)
                            selectionState.selectChannel(variant)
                            selectedChannelForVariants = nil
                        },
                        onDismiss: {
                            selectedChannelForVariants = nil
                            if let id = lastFocusedChannelId { focusedMenuChannelId = id }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
        }
        .onChange(of: selectedChannelForVariants) { oldValue, newValue in
            if newValue == nil, let id = lastFocusedChannelId {
                focusedMenuChannelId = id
            }
        }
        .onAppear {
            if serviceManager.availableChannels.isEmpty { serviceManager.loadChannels() }
        }
        // District selection is handled inline via Menu; no sheet presentation
    }
    
    // Selection is handled inline in the list via Button/Menu
    private func handleChannelSelection(_ channel: DRChannel) { }
}

/// A wrapper view that applies a ButtonStyle to any Menu label
struct MenuLabelButtonStyle<Style: ButtonStyle, Label: View>: View {
    let style: Style
    let label: Label
    
    init(style: Style, @ViewBuilder label: () -> Label) {
        self.style = style
        self.label = label()
    }
    
    var body: some View {
        Button(action: {}) {
            label
        }
        .buttonStyle(style)
        .allowsHitTesting(false) // Let Menu handle taps
    }
}

#endif

