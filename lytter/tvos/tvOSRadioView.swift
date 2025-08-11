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

                VStack(alignment: .leading, spacing: 24) {
                    Text("Radio")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)

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
                                    } else {
                                        Menu {
                                            ForEach(variants, id: \.id) { variant in
                                                Button(action: {
                                                    serviceManager.playChannel(variant)
                                                    selectionState.selectChannel(variant)
                                                }) {
                                                    Text(variant.district ?? variant.title)
                                                }
                                            }
                                        } label: {
                                            tvOSChannelCard(channel: channel)
                                                .frame(width: 460, height: 300)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                        }
                    }
                }
                .padding(.top, 40)
                .padding(.horizontal, 60)
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
#endif

