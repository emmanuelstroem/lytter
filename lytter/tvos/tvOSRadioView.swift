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
    @State private var showingDistrictsForChannel: DRChannel?

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
                                    Button(action: { handleChannelSelection(channel) }) {
                                        tvOSChannelCard(channel: channel)
                                            .frame(width: 460, height: 300)
                                    }
                                    .buttonStyle(.card)
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
        .sheet(item: $showingDistrictsForChannel) { primary in
            tvOSDistrictSelectionSheet(
                primaryName: primary.name,
                variants: serviceManager.availableChannels.filter { $0.name == primary.name }
            ) { selected in
                serviceManager.playChannel(selected)
                selectionState.selectChannel(selected)
            }
        }
    }

    private func handleChannelSelection(_ channel: DRChannel) {
        // Find all variants for this base name
        let variants = serviceManager.availableChannels.filter { $0.name == channel.name }
        if variants.count <= 1 {
            serviceManager.playChannel(channel)
            selectionState.selectChannel(channel)
        } else {
            showingDistrictsForChannel = channel
        }
    }
}
#endif

